module bw_stats_core #(
  parameter bw_mon_pkg::bw_basis_t WINDOW_BASIS = bw_mon_pkg::BW_NS,
  parameter bw_mon_pkg::bw_u64_t WINDOW_WIDTH = 0,
  parameter bw_mon_pkg::bw_u64_t UPDATE_STRIDE = 0
) (
  input string scope_id,
  input bw_mon_pkg::bw_record_t record,
  input bit record_toggle,
  input logic stats_reset_n = 1'b1,
  input bw_mon_pkg::bw_control_t member_control = '0,
  input bit member_control_toggle = 1'b0,
  output bw_mon_pkg::bw_u64_t accepted_record_seq = 0,
  output bw_mon_pkg::bw_u64_t accepted_control_count = 0,
  output bw_mon_pkg::bw_u64_t stats_epoch = 0,
  output bw_mon_pkg::bw_u64_t result_seq = 0,
  output bw_mon_pkg::bw_u64_t total_bytes = 0,
  output bw_mon_pkg::bw_u64_t total_events = 0,
  output bw_mon_pkg::bw_u64_t window_start_ticks = 0,
  output bw_mon_pkg::bw_u64_t window_end_ticks = 0,
  output bw_mon_pkg::bw_u64_t window_start_cycle = 0,
  output bw_mon_pkg::bw_u64_t window_end_cycle = 0,
  output bw_mon_pkg::bw_u64_t coverage_ticks = 0,
  output bw_mon_pkg::bw_u64_t coverage_cycles = 0,
  output bw_mon_pkg::bw_u64_t window_bytes = 0,
  output bw_mon_pkg::bw_u64_t window_events = 0,
  output real bandwidth_gbps = 0.0,
  output real bytes_per_cycle = 0.0,
  output bit window_warmup = 1,
  output bit window_full = 0,
  output bit bytes_complete = 1,
  output bit events_complete = 1,
  output bit denominator_valid = 0,
  output bit window_valid = 0,
  output bit member_reset_coverage = 0
);
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_record_t history[$];
  bw_record_t pending_frames[$];
  bw_u64_t pending_timers[$];
  typedef struct packed {
    bw_u64_t timestamp_ticks;
    logic reset_n;
  } reset_action_t;
  reset_action_t pending_resets[$];
  bw_control_t pending_member_controls[$];
  typedef struct packed {
    bw_u64_t start_ticks;
    bw_u64_t end_ticks;
    bit unknown_reset;
    bit known_reset;
  } quality_interval_t;
  typedef struct packed {
    bw_u64_t start_ticks;
    logic reset_n;
  } active_quality_t;
  quality_interval_t quality_intervals[$];
  active_quality_t active_quality[int];
  bw_u64_t member_control_sequences[int];
  bw_u64_t member_control_times[int];
  bw_u64_t requested_actions=0, consumed_actions=0;
  bw_u64_t timer_requests=0, timer_receipts=0, timer_schedule_seq=0;
  bw_u64_t stats_start_ticks;
  bw_u64_t last_assert_ticks=0;
  bit assertion_observed=0, reset_enqueued=0, reset_applied=0;
  logic observed_reset_n, current_reset_n=1'b1;
  bw_u64_t next_update_ticks;
  bw_u64_t retained_bytes = 0, retained_events = 0;
  bw_u64_t unknown_bytes = 0, unknown_events = 0, reset_entries = 0;
  bw_u64_t last_record_seq = 0;
  bw_u64_t last_frame_ticks = 0, last_edge_index = 0;
  // Idle edges are physical cycle boundaries too. Keep their integer times
  // separately from the sparse event/quality history used by both bases.
  bw_u64_t cycle_boundary_ticks[$];
  bw_u64_t boundary_first_cycle, cycle_origin, next_update_cycle;
  bit cycle_initialized = 0;
  bit initialized = 0;

  task automatic update_quality(int key, logic reset_level, bw_u64_t at_ticks);
    quality_interval_t interval;
    active_quality_t active;
    if (active_quality.exists(key)) begin
      active=active_quality[key];
      if (active.reset_n === reset_level) return;
      if (at_ticks > active.start_ticks) begin
        interval.start_ticks=active.start_ticks; interval.end_ticks=at_ticks;
        interval.unknown_reset=$isunknown(active.reset_n);
        interval.known_reset=(active.reset_n === 1'b0);
        check_queue_growth(quality_intervals.size(),scope_id);
        quality_intervals.push_back(interval);
      end
      active_quality.delete(key);
    end
    if (reset_level !== 1'b1) begin
      active.start_ticks=at_ticks; active.reset_n=reset_level;
      active_quality[key]=active;
    end
  endtask

  task automatic window_control_quality(bw_u64_t left, bw_u64_t right);
    int i;
    quality_interval_t interval;
    i=0;
    while (i<quality_intervals.size()) begin
      interval=quality_intervals[i];
      if (interval.end_ticks<=left) begin
        quality_intervals.delete(i);
        continue;
      end
      if (interval.start_ticks<right && interval.end_ticks>left) begin
        if (interval.unknown_reset) begin bytes_complete=0; events_complete=0; end
        if (interval.known_reset) member_reset_coverage=1;
      end
      i++;
    end
    foreach (active_quality[key]) begin
      if (active_quality[key].start_ticks<right) begin
        if ($isunknown(active_quality[key].reset_n)) begin bytes_complete=0; events_complete=0; end
        if (active_quality[key].reset_n === 1'b0) member_reset_coverage=1;
      end
    end
  endtask

  task automatic initialize_state();
    if (!initialized) begin
      next_update_ticks = checked_add(stats_start_ticks,
                          ns_to_ticks(UPDATE_STRIDE,scope_id),scope_id);
      initialized = 1;
    end
  endtask

  task automatic publish_window(bw_u64_t at_ticks, bw_u64_t at_cycle = 0);
    bw_record_t expired;
    bw_u64_t width_ticks, left, left_cycle;
    if (WINDOW_BASIS == BW_NS) begin
      width_ticks = ns_to_ticks(WINDOW_WIDTH,scope_id);
      left = (at_ticks-stats_start_ticks >= width_ticks) ? at_ticks-width_ticks
                                                       : stats_start_ticks;
      window_full=(at_ticks-stats_start_ticks>=width_ticks);
    end else begin
      left_cycle = (at_cycle-cycle_origin >= WINDOW_WIDTH) ? at_cycle-WINDOW_WIDTH
                                                         : cycle_origin;
      left=cycle_boundary_ticks[0];
      window_start_cycle=left_cycle; window_end_cycle=at_cycle;
      coverage_cycles=at_cycle-left_cycle;
      window_full=(at_cycle-cycle_origin>=WINDOW_WIDTH);
    end
    // Rolling exact totals avoid an O(window-history) scan on each update.
    while (history.size() != 0 && ((WINDOW_BASIS == BW_NS && history[0].timestamp_ticks < left) ||
           (WINDOW_BASIS == BW_CYCLE && history[0].edge_index < left_cycle))) begin
      expired=history.pop_front();
      retained_bytes -= expired.byte_inc;
      retained_events -= expired.event_inc;
      if (!expired.bytes_complete) unknown_bytes--;
      if (!expired.events_complete) unknown_events--;
      if (expired.reset_points != 0) reset_entries--;
    end
    window_start_ticks=left; window_end_ticks=at_ticks;
    coverage_ticks=at_ticks-left;
    window_bytes=retained_bytes; window_events=retained_events;
    bytes_complete=(unknown_bytes==0); events_complete=(unknown_events==0);
    member_reset_coverage=(reset_entries!=0);
    window_control_quality(left,at_ticks);
    denominator_valid=(coverage_ticks!=0);
    window_warmup=!window_full;
    window_valid=window_full && bytes_complete && denominator_valid;
    if (denominator_valid)
      bandwidth_gbps=real'(window_bytes)*real'(BW_TICKS_PER_NS)/real'(coverage_ticks);
    else bandwidth_gbps=0.0;
    if (WINDOW_BASIS == BW_CYCLE && coverage_cycles != 0)
      bytes_per_cycle=real'(window_bytes)/real'(coverage_cycles);
    result_seq=checked_add(result_seq,1,scope_id);
  endtask

  task automatic clear_statistics(bw_u64_t at_ticks);
    stats_epoch=checked_add(stats_epoch,1,scope_id);
    stats_start_ticks=at_ticks;
    history.delete(); cycle_boundary_ticks.delete();
    quality_intervals.delete(); active_quality.delete(-1);
    retained_bytes=0; retained_events=0;
    unknown_bytes=0; unknown_events=0; reset_entries=0;
    total_bytes=0; total_events=0;
    window_start_ticks=0; window_end_ticks=0;
    window_start_cycle=0; window_end_cycle=0;
    coverage_ticks=0; coverage_cycles=0;
    window_bytes=0; window_events=0;
    bandwidth_gbps=0.0; bytes_per_cycle=0.0;
    window_warmup=1; window_full=0;
    bytes_complete=1; events_complete=1;
    denominator_valid=0; window_valid=0; member_reset_coverage=0;
    initialized=0; cycle_initialized=0;
    // Transport positions, acceptance receipts and result sequence never rewind.
    timer_schedule_seq=checked_add(timer_schedule_seq,1,scope_id);
  endtask

  task automatic enqueue_reset();
    reset_action_t action;
    if (reset_enqueued && observed_reset_n === stats_reset_n) return;
    check_monitor_time($time,scope_id);
    observed_reset_n=stats_reset_n;
    reset_enqueued=1;
    action.timestamp_ticks=$time; action.reset_n=stats_reset_n;
    check_queue_growth(pending_resets.size(),scope_id);
    pending_resets.push_back(action);
    requested_actions=checked_add(requested_actions,1,scope_id);
  endtask

  task automatic apply_reset(reset_action_t action);
    if (action.reset_n === 1'b0 && (!reset_applied || current_reset_n !== 1'b0)) begin
      clear_statistics(action.timestamp_ticks);
      last_assert_ticks=action.timestamp_ticks;
      assertion_observed=1;
    end else if (reset_applied && current_reset_n === 1'b0 && action.reset_n !== 1'b0) begin
      stats_start_ticks=action.timestamp_ticks;
      initialized=0;
      initialize_state();
      timer_schedule_seq=checked_add(timer_schedule_seq,1,scope_id);
    end else if (!reset_applied) begin
      stats_start_ticks=measurement_start_ticks;
      initialize_state();
    end
    current_reset_n=action.reset_n;
    reset_applied=1;
    update_quality(-1,action.reset_n,action.timestamp_ticks);
  endtask

  task automatic apply_member_control(bw_control_t incoming);
    int key;
    bw_u64_t expected_seq;
    key=int'(incoming.point_handle);
    check_monitor_time(incoming.timestamp_ticks,scope_id);
    if (incoming.timestamp_ticks>$time)
      core_error("CONTROL_TIME",scope_id,"control timestamp is in the future");
    if (incoming.point_handle>=expected_point_count)
      core_error("POINT_REFERENCE",scope_id,
        $sformatf("control point_handle=%0d registered_points=%0d",incoming.point_handle,expected_point_count));
    expected_seq=member_control_sequences.exists(key) ?
                 checked_add(member_control_sequences[key],1,scope_id) : 1;
    if (incoming.control_seq!=expected_seq)
      core_error("CONTROL_SEQUENCE",scope_id,
        $sformatf("point_handle=%0d expected=%0d received=%0d",key,expected_seq,incoming.control_seq));
    if (member_control_times.exists(key) && incoming.timestamp_ticks<member_control_times[key])
      core_error("CONTROL_TIME",scope_id,$sformatf("point_handle=%0d time_ticks=%0d",key,incoming.timestamp_ticks));
    member_control_sequences[key]=incoming.control_seq;
    member_control_times[key]=incoming.timestamp_ticks;
    update_quality(key,incoming.reset_n,incoming.timestamp_ticks);
    accepted_control_count=checked_add(accepted_control_count,1,scope_id);
  endtask

  task automatic publish_due(bw_u64_t through_ticks);
    initialize_state();
    while (next_update_ticks <= through_ticks) begin
      publish_window(next_update_ticks);
      next_update_ticks=checked_add(next_update_ticks,ns_to_ticks(UPDATE_STRIDE,scope_id),scope_id);
    end
  endtask

  // One run-to-completion entry owns state. A frame arriving before the timer
  // publishes all due [left,T) results before accounting T's event; a timer
  // arriving first advances the same schedule, so either order gives one result.
  task automatic dispatch(bit is_frame, bw_record_t incoming, bw_u64_t now_ticks);
    bw_u64_t left_cycle, discarded_boundary;
    if (!monitor_ready) return;
    if (is_frame) begin
      if (incoming.record_seq != checked_add(last_record_seq,1,scope_id))
        core_error("RECORD_SEQUENCE",scope_id,
                   $sformatf("expected=%0d received=%0d",last_record_seq+1,incoming.record_seq));
      if (last_record_seq!=0 && incoming.timestamp_ticks<=last_frame_ticks)
        core_error("RECORD_TIME",scope_id,"sampling timestamps must strictly increase");
      if (last_record_seq!=0 && incoming.edge_index!=checked_add(last_edge_index,1,scope_id))
        core_error("EDGE_SEQUENCE",scope_id,
                   $sformatf("expected=%0d received=%0d",last_edge_index+1,incoming.edge_index));
      last_record_seq=incoming.record_seq; last_frame_ticks=incoming.timestamp_ticks;
      last_edge_index=incoming.edge_index;
      if (current_reset_n === 1'b0 || incoming.timestamp_ticks < stats_start_ticks ||
          (assertion_observed && incoming.timestamp_ticks==last_assert_ticks)) begin
        accepted_record_seq=incoming.record_seq;
        return;
      end
      if (WINDOW_BASIS == BW_CYCLE) begin
        if (!cycle_initialized) begin
          cycle_origin=incoming.edge_index;
          boundary_first_cycle=cycle_origin;
          next_update_cycle=checked_add(cycle_origin,UPDATE_STRIDE,scope_id);
          cycle_initialized=1;
        end
        check_queue_growth(cycle_boundary_ticks.size(),scope_id);
        cycle_boundary_ticks.push_back(incoming.timestamp_ticks);
        left_cycle=(incoming.edge_index-cycle_origin>=WINDOW_WIDTH) ?
                    incoming.edge_index-WINDOW_WIDTH : cycle_origin;
        while (boundary_first_cycle<left_cycle) begin
          discarded_boundary=cycle_boundary_ticks.pop_front();
          boundary_first_cycle=checked_add(boundary_first_cycle,1,scope_id);
        end
        if (incoming.edge_index == next_update_cycle) begin
          publish_window(now_ticks,incoming.edge_index);
          next_update_cycle=checked_add(next_update_cycle,UPDATE_STRIDE,scope_id);
        end
      end
    end
    if (current_reset_n === 1'b0) return;
    if (WINDOW_BASIS == BW_NS) publish_due(now_ticks);
    if (!is_frame) return;
    total_bytes=checked_add(total_bytes,incoming.byte_inc,scope_id);
    total_events=checked_add(total_events,incoming.event_inc,scope_id);
    retained_bytes=checked_add(retained_bytes,incoming.byte_inc,scope_id);
    retained_events=checked_add(retained_events,incoming.event_inc,scope_id);
    if (!incoming.bytes_complete) unknown_bytes=checked_add(unknown_bytes,1,scope_id);
    if (!incoming.events_complete) unknown_events=checked_add(unknown_events,1,scope_id);
    if (incoming.reset_points!=0) reset_entries=checked_add(reset_entries,1,scope_id);
    if (incoming.byte_inc!=0 || incoming.event_inc!=0 || !incoming.bytes_complete ||
        !incoming.events_complete || incoming.reset_points!=0) begin
      check_queue_growth(history.size(),scope_id);
      history.push_back(incoming);
    end
    accepted_record_seq=incoming.record_seq;
  endtask

  always @(record_toggle) begin
    if (monitor_ready && record.record_seq != 0) begin
      if (record.timestamp_ticks>$time)
        core_error("RECORD_TIME",scope_id,"record timestamp is in the future");
      check_queue_growth(pending_frames.size(),scope_id);
      pending_frames.push_back(record);
      requested_actions=checked_add(requested_actions,1,scope_id);
    end
  end
  always @(stats_reset_n) if (monitor_ready) enqueue_reset();
  always @(member_control_toggle) begin
    if (monitor_ready && member_control.control_seq!=0) begin
      check_queue_growth(pending_member_controls.size(),scope_id);
      pending_member_controls.push_back(member_control);
      requested_actions=checked_add(requested_actions,1,scope_id);
    end
  end

  task automatic drain_actions();
    reset_action_t reset_action;
    bw_record_t frame;
    bw_control_t control;
    bw_u64_t timer_tick;
    check_monitor_time($time,scope_id);
    while (consumed_actions != requested_actions) begin
      if (pending_resets.size()!=0) begin
        reset_action=pending_resets.pop_front();
        apply_reset(reset_action);
      end else if (pending_member_controls.size()!=0) begin
        control=pending_member_controls.pop_front();
        apply_member_control(control);
      end else if (pending_frames.size()!=0) begin
        frame=pending_frames.pop_front();
        dispatch(1,frame,frame.timestamp_ticks);
      end else begin
        timer_tick=pending_timers.pop_front();
        dispatch(0,'0,timer_tick);
        timer_receipts=checked_add(timer_receipts,1,scope_id);
      end
      consumed_actions=checked_add(consumed_actions,1,scope_id);
    end
  endtask

  bw_stats_core_scheduler scheduler();

  initial begin
    bw_u64_t observed_schedule, due_tick, request_number;
    wait(monitor_ready);
    enqueue_reset();
    wait(reset_applied);
    if (WINDOW_BASIS == BW_NS) begin
      forever begin
        observed_schedule=timer_schedule_seq;
        if (current_reset_n === 1'b0) begin
          wait(timer_schedule_seq != observed_schedule);
        end else begin
          due_tick=next_update_ticks;
          if ($time < due_tick) begin
            fork : wait_for_timer
              begin #(due_tick-$time); end
              begin wait(timer_schedule_seq != observed_schedule); end
            join_any
            disable wait_for_timer;
          end
          if (timer_schedule_seq == observed_schedule && $time >= due_tick) begin
            check_queue_growth(pending_timers.size(),scope_id);
            pending_timers.push_back($time);
            timer_requests=checked_add(timer_requests,1,scope_id);
            request_number=timer_requests;
            requested_actions=checked_add(requested_actions,1,scope_id);
            wait(timer_receipts >= request_number);
          end
        end
      end
    end
  end
endmodule

program bw_stats_core_scheduler;
  timeunit 1fs; timeprecision 1fs;
  initial forever begin
    wait(bw_stats_core.requested_actions != bw_stats_core.consumed_actions);
    bw_stats_core.drain_actions();
  end
endprogram
