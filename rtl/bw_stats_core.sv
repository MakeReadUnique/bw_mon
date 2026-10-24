module bw_stats_core #(
  parameter bw_mon_pkg::bw_basis_t WINDOW_BASIS = bw_mon_pkg::BW_NS,
  parameter bw_mon_pkg::bw_u64_t WINDOW_WIDTH = 0,
  parameter bw_mon_pkg::bw_u64_t UPDATE_STRIDE = 0
) (
  input string scope_id,
  input bw_mon_pkg::bw_record_t record,
  input bit record_toggle,
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
  bw_u64_t next_update_ticks;
  bw_u64_t retained_bytes = 0, retained_events = 0;
  bw_u64_t unknown_bytes = 0, unknown_events = 0, reset_entries = 0;
  bw_u64_t last_record_seq = 0;
  bw_u64_t last_frame_ticks = 0;
  bit initialized = 0;

  task automatic initialize_state();
    if (!initialized) begin
      next_update_ticks = checked_add(measurement_start_ticks,
                          ns_to_ticks(UPDATE_STRIDE,scope_id),scope_id);
      initialized = 1;
    end
  endtask

  task automatic publish_window(bw_u64_t at_ticks);
    bw_record_t expired;
    bw_u64_t width_ticks, left;
    width_ticks = ns_to_ticks(WINDOW_WIDTH,scope_id);
    left = (at_ticks-measurement_start_ticks >= width_ticks) ? at_ticks-width_ticks
                                                          : measurement_start_ticks;
    // Rolling exact totals avoid an O(window-history) scan on each update.
    while (history.size() != 0 && history[0].timestamp_ticks < left) begin
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
    denominator_valid=(coverage_ticks!=0);
    window_full=(at_ticks-measurement_start_ticks>=width_ticks);
    window_warmup=!window_full;
    window_valid=window_full && bytes_complete && denominator_valid;
    if (denominator_valid)
      bandwidth_gbps=real'(window_bytes)*real'(BW_TICKS_PER_NS)/real'(coverage_ticks);
    else bandwidth_gbps=0.0;
    result_seq=checked_add(result_seq,1,scope_id);
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
    if (!monitor_ready) return;
    publish_due(now_ticks);
    if (!is_frame) return;
    if (incoming.record_seq != checked_add(last_record_seq,1,scope_id))
      core_error("RECORD_SEQUENCE",scope_id,
                 $sformatf("expected=%0d received=%0d",last_record_seq+1,incoming.record_seq));
    if (last_record_seq!=0 && incoming.timestamp_ticks<=last_frame_ticks)
      core_error("RECORD_TIME",scope_id,"sampling timestamps must strictly increase");
    last_record_seq=incoming.record_seq; last_frame_ticks=incoming.timestamp_ticks;
    total_bytes=checked_add(total_bytes,incoming.byte_inc,scope_id);
    total_events=checked_add(total_events,incoming.event_inc,scope_id);
    retained_bytes=checked_add(retained_bytes,incoming.byte_inc,scope_id);
    retained_events=checked_add(retained_events,incoming.event_inc,scope_id);
    if (!incoming.bytes_complete) unknown_bytes=checked_add(unknown_bytes,1,scope_id);
    if (!incoming.events_complete) unknown_events=checked_add(unknown_events,1,scope_id);
    if (incoming.reset_points!=0) reset_entries=checked_add(reset_entries,1,scope_id);
    if (incoming.byte_inc!=0 || incoming.event_inc!=0 || !incoming.bytes_complete ||
        !incoming.events_complete || incoming.reset_points!=0)
      history.push_back(incoming);
  endtask

  always @(record_toggle) begin
    if (monitor_ready && record.record_seq != 0)
      dispatch(1,record,record.timestamp_ticks);
  end
  initial begin
    wait(monitor_ready);
    forever begin
      #(ns_to_ticks(UPDATE_STRIDE,scope_id));
      dispatch(0,'0,$time);
    end
  end
endmodule
