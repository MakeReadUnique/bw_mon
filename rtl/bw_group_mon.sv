module bw_group_mon #(
  parameter string GROUP_ID="",
  parameter logic [1:0] WINDOW_BASIS=bw_mon_pkg::BW_NS,
  parameter logic [63:0] WINDOW_WIDTH=0,
  parameter logic [63:0] UPDATE_STRIDE=bw_mon_pkg::BW_CFG_OMITTED,
  parameter logic [1:0] EPISODE_ENABLE = 0,
  parameter logic [63:0] SILENCE_THRESHOLD = bw_mon_pkg::BW_CFG_OMITTED,
  parameter logic [1:0] PHASE_ENABLE = 0,
  parameter logic [63:0] PHASE_N = 0,
  parameter logic [63:0] PHASE_MIN_SPAN = 0,
  parameter logic [63:0] PHASE_K = 0,
  parameter real PHASE_STEADY_ENTER_ABS = -1.0,
  parameter real PHASE_STEADY_ENTER_REL = -1.0,
  parameter real PHASE_STEADY_EXIT_ABS = -1.0,
  parameter real PHASE_STEADY_EXIT_REL = -1.0,
  parameter real PHASE_RMS_ENTER_ABS = -1.0,
  parameter real PHASE_RMS_ENTER_REL = -1.0,
  parameter real PHASE_RMS_EXIT_ABS = -1.0,
  parameter real PHASE_RMS_EXIT_REL = -1.0,
  parameter real PHASE_TREND_ABS = -1.0,
  parameter real PHASE_TREND_REL = -1.0
) (
  input logic clk,
  input logic reset_n
);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string scope_id,monitor_path;
  bw_scope_t scope_kind=BW_GROUP;
  // Effective public configuration after omission defaults are applied.
  bw_u64_t effective_stride,effective_silence;
  int group_handle,transport_source,direct_member_count,recursive_point_count;
  int initial_control_count;
  bw_record_t raw_record;
  bw_control_t raw_control,core_control;
  bit record_toggle=0,control_toggle=0,core_control_toggle=0;
  bw_u64_t accepted_record_seq,accepted_control_count;
  bw_u64_t raw_sequence=0,control_result_seq=0;
  bw_u64_t stats_epoch,result_seq,total_bytes,total_events;
  bw_u64_t window_start_ticks,window_end_ticks,window_start_cycle,window_end_cycle;
  bw_u64_t coverage_ticks,coverage_cycles,window_bytes,window_events;
  real bandwidth_gbps,bytes_per_cycle;
  bit window_warmup,window_full,bytes_complete,events_complete;
  bit denominator_valid,window_valid,member_reset_coverage;
  `include "bw_analysis_public.svh"

  bw_u64_t progress_watermark_ticks=0;
  typedef struct packed {
    bw_u64_t timestamp_ticks;
    bw_u64_t edge_index;
  } expected_edge_t;
  expected_edge_t expected_edges[$];
  bw_u64_t expected_notice=0,expected_edge_index=0,last_expected_ticks=0,deadline_alarm_seq=0;
  bit deferred_failure=0;
  string deferred_failure_code,deferred_failure_detail;
  bit reset_observer_ready=0;
  localparam bit external_reset_capture=0;
  function void apply_captured_reset(logic value,bw_u64_t ticks);core.enqueue_reset(value,ticks);endfunction
  `include "bw_reset_capture.svh"

  initial begin
    core.use_external_reset_capture();
    monitor_path=$sformatf("%m");scope_id=GROUP_ID;
    effective_stride=resolve_update_stride(UPDATE_STRIDE,WINDOW_WIDTH);
    effective_silence=resolve_silence_threshold(SILENCE_THRESHOLD,EPISODE_ENABLE);
    // Reject raw configuration before narrowing into legacy internal enums/bits.
    if($isunknown({WINDOW_BASIS,WINDOW_WIDTH,effective_stride}) || !(WINDOW_BASIS inside {BW_NS,BW_CYCLE}))
      core_error("WINDOW_CONFIG",scope_id,"basis, W and S must be known; basis must be BW_NS/BW_CYCLE");
    validate_window(bw_basis_t'(WINDOW_BASIS),WINDOW_WIDTH,effective_stride,scope_id);
    if($isunknown(EPISODE_ENABLE) || !(EPISODE_ENABLE inside {0,1}))
      core_error("EPISODE_CONFIG",scope_id,"episode enable must be known0/1");
    if($isunknown(PHASE_ENABLE) || !(PHASE_ENABLE inside {0,1}))
      core_error("PHASE_CONFIG",scope_id,"phase enable must be known0/1");
    validate_episode_config(EPISODE_ENABLE,effective_silence,bw_basis_t'(WINDOW_BASIS),scope_id);
    validate_phase_config(PHASE_ENABLE,EPISODE_ENABLE,bw_basis_t'(WINDOW_BASIS),PHASE_N,PHASE_MIN_SPAN,PHASE_K,
      PHASE_STEADY_ENTER_ABS,PHASE_STEADY_ENTER_REL,PHASE_STEADY_EXIT_ABS,PHASE_STEADY_EXIT_REL,
      PHASE_RMS_ENTER_ABS,PHASE_RMS_ENTER_REL,PHASE_RMS_EXIT_ABS,PHASE_RMS_EXIT_REL,
      PHASE_TREND_ABS,PHASE_TREND_REL,scope_id);
    initialize_reset_capture(monitor_path,"reset_n");
    group_handle=register_group_owner(scope_id,monitor_path,bw_basis_t'(WINDOW_BASIS),
                                      WINDOW_WIDTH,effective_stride);
    transport_source=group_source_handle(group_handle);
    raw_record='0;raw_control='0;core_control='0;
    declare_scope_preparation(transport_source);
    fork begin
      #(1);
      if (!monitor_configured)
        core_error("SETUP_MISSING",scope_id,
          "a connected aggregation group requires exactly one bw_mon_setup");
    end join_none
    wait(configuration_sealed);
    direct_member_count=group_member_count(group_handle);
    recursive_point_count=group_recursive_point_count(group_handle);
    initial_control_count=registered_groups[group_handle].initial_control_count;
    wait(core.scope_id==scope_id);
    reset_observer_ready=1;bw_native_reset_snapshot(reset_capture_handle);
    // Public points supply initial quality through the real routes. A source
    // registered directly at the component seam owns its own control stimulus.
    wait(core.reset_applied && accepted_control_count==initial_control_count);
    note_scope_prepared();
    wait(monitor_ready);
  end
  final begin
    if(!monitor_configured && !core_failure_pending())
      core_error("SETUP_MISSING",scope_id,"simulation ended without bw_mon_setup");
  end

  task automatic refresh_progress();
    bw_u64_t watermark;
    watermark=group_input_watermark(group_handle);
    if (expected_edges.size()!=0 && expected_edges[0].timestamp_ticks<watermark)
      watermark=expected_edges[0].timestamp_ticks;
    progress_watermark_ticks=watermark;
    set_source_progress(transport_source,watermark);
  endtask

  always @(posedge clk) begin : capture_expected_edge
    expected_edge_t expected;
    if (monitor_ready && $time>measurement_start_ticks) begin
      check_monitor_time($time,scope_id);
      if (expected_edge_index!=0 && $time<=last_expected_ticks)
        core_error("GROUP_CLOCK",scope_id,"actual sampling timestamps must strictly increase");
      expected_edge_index=checked_add(expected_edge_index,1,scope_id);last_expected_ticks=$time;
      expected.timestamp_ticks=$time;expected.edge_index=expected_edge_index;
      check_storage_growth(expected_edges.size(),scope_id,"group.expected",expected.timestamp_ticks,expected.edge_index,expected.edge_index);
      if(core_failure_seen)disable capture_expected_edge;
      expected_edges.push_back(expected);
      expected_notice=checked_add(expected_notice,1,scope_id);refresh_progress();
    end
  end

  task automatic commit_control(int member_index,bw_control_frame_t envelope);
    bw_u64_t receipt;
    receipt=checked_add(accepted_control_count,1,scope_id);
    core_control=envelope.value;core_control_toggle<=!core_control_toggle;
    wait(accepted_control_count>=receipt);
    publish_control(transport_source,envelope.value);
    raw_control=envelope.value;control_result_seq=checked_add(control_result_seq,1,scope_id);
    control_toggle<=!control_toggle;
    acknowledge_member_control(group_handle,member_index,envelope.transport_seq);
    refresh_progress();
  endtask

  task automatic commit_frame(expected_edge_t expected);
    bw_record_t member,frame;
    expected_edge_t discarded;
    frame='0;frame.timestamp_ticks=expected.timestamp_ticks;frame.edge_index=expected.edge_index;
    frame.record_seq=checked_add(raw_sequence,1,scope_id);
    frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1'b1;
    for (int m=0;m<direct_member_count;m++) begin
      if (!peek_member_frame(group_handle,m,member))
        core_error("COLLECTOR_STATE",scope_id,"complete input disappeared before commit");
      frame.byte_inc=checked_add(frame.byte_inc,member.byte_inc,scope_id);
      frame.event_inc=checked_add(frame.event_inc,member.event_inc,scope_id);
      frame.reset_points=checked_add(frame.reset_points,member.reset_points,scope_id);
      frame.bytes_complete&=member.bytes_complete;frame.events_complete&=member.events_complete;
    end
    raw_sequence=frame.record_seq;raw_record=frame;
    publish_frame(transport_source,frame);record_toggle<=!record_toggle;
    wait(accepted_record_seq>=frame.record_seq);
    for (int m=0;m<direct_member_count;m++)
      acknowledge_member_frame(group_handle,m,frame.record_seq);
    discarded=expected_edges.pop_front();expected_notice=checked_add(expected_notice,1,scope_id);
    refresh_progress();
  endtask

  task automatic collect_inputs();
    bw_notification notice;
`ifdef BW_MON_TEST_SCHEDULING
    bw_test_consumer_gate test_gate;
`endif
    bw_u64_t seen_notice,seen_expected;
    bw_control_frame_t candidate,control;
    bw_record_t frame;
    int selected_control,source;
    bit all_frames;
    wait(configuration_sealed);
`ifdef BW_MON_TEST_SCHEDULING
    test_gate=bw_test_gate_for(scope_id);
`endif
    notice=group_notification(group_handle);
    forever begin
`ifdef BW_MON_TEST_SCHEDULING
      wait(!test_gate.paused);
`endif
      seen_notice=notice.seq;seen_expected=expected_notice;refresh_progress();
      selected_control=-1;candidate='0;
      for (int m=0;m<direct_member_count;m++) begin
        if (peek_member_control(group_handle,m,control) &&
            (selected_control<0 || control.value.timestamp_ticks<candidate.value.timestamp_ticks)) begin
          candidate=control;selected_control=m;
        end
      end
      if (selected_control>=0 && candidate.value.timestamp_ticks<=direct_source_watermark(group_handle) &&
          (expected_edges.size()==0 || candidate.value.timestamp_ticks<=expected_edges[0].timestamp_ticks)) begin
        commit_control(selected_control,candidate);continue;
      end
      all_frames=(expected_edges.size()!=0);
      for (int m=0;m<direct_member_count;m++) begin
        if (peek_member_frame(group_handle,m,frame)) begin
          source=member_source(group_handle,m);
          if (expected_edges.size()==0) all_frames=0;
          else if (frame.edge_index!=expected_edges[0].edge_index || frame.timestamp_ticks!=expected_edges[0].timestamp_ticks)
            core_error("FRAME_ALIGNMENT",scope_id,group_missing_detail(group_handle,
              expected_edges[0].edge_index,expected_edges[0].timestamp_ticks));
        end else all_frames=0;
      end
      if (all_frames && expected_edges[0].timestamp_ticks<=direct_source_watermark(group_handle)) begin
        commit_frame(expected_edges[0]);continue;
      end
      wait(notice.seq!=seen_notice || expected_notice!=seen_expected);
    end
  endtask

  bw_group_collector_scheduler collector();

  function automatic bit deadline_ok();
    bw_record_t frame;
    if (expected_edges.size()==0) begin
      for (int m=0;m<direct_member_count;m++)
        if (peek_member_frame(group_handle,m,frame)) return 0;
      return 1;
    end
    if ($time<checked_add(expected_edges[0].timestamp_ticks,missing_record_timeout_ticks,scope_id)) return 1;
    return group_frame_inputs_ready(group_handle,expected_edges[0].edge_index,expected_edges[0].timestamp_ticks);
  endfunction

  function automatic void capture_deadline_failure();
    bw_record_t frame;
    int source;
    deferred_failure=!deadline_ok();
    if (deferred_failure) begin
      if (expected_edges.size()==0) begin
        for (int m=0;m<direct_member_count;m++)
          if (peek_member_frame(group_handle,m,frame)) begin
            source=member_source(group_handle,m);
            deferred_failure_code="UNEXPECTED_FRAME";
            deferred_failure_detail=$sformatf("source=%s edge=%0d ticks=%0d without actual group sampling edge",
                source_name(source),frame.edge_index,frame.timestamp_ticks);
          end
      end else begin
        deferred_failure_code="FRAME_TIMEOUT";
        deferred_failure_detail=group_missing_detail(group_handle,
          expected_edges[0].edge_index,expected_edges[0].timestamp_ticks);
      end
    end
    set_deferred_core_failure(group_handle+1,deferred_failure);
  endfunction

  function automatic void report_frame_timeout();
    if(deferred_failure)deferred_core_error(deferred_failure_code,scope_id,deferred_failure_detail);
  endfunction

  initial begin : deadline_checks
    bw_notification notice;
    wait(monitor_ready);notice=group_notification(group_handle);
    forever begin
      capture_deadline_failure();
      INPUTS_COMPLETE: assert final (!deferred_failure)
        else report_frame_timeout();
      @(notice.seq or expected_notice or deadline_alarm_seq or accepted_record_seq);
    end
  end

  initial begin : oldest_deadline
    bw_u64_t seen,due;
    wait(monitor_ready);
    forever begin
      seen=expected_notice;
      if (expected_edges.size()==0) wait(expected_notice!=seen);
      else begin
        due=checked_add(expected_edges[0].timestamp_ticks,missing_record_timeout_ticks,scope_id);
        if ($time<due) #(due-$time);
        deadline_alarm_seq=checked_add(deadline_alarm_seq,1,scope_id);
        // The old front may have completed while this timer slept. Re-arm
        // a newer future deadline immediately; only an expired front waits
        // for same-slot completion (or the deferred failure decision).
        if (expected_edges.size()!=0 &&
            $time>=checked_add(expected_edges[0].timestamp_ticks,missing_record_timeout_ticks,scope_id)) begin
          seen=expected_notice;
          wait(expected_notice!=seen);
        end
      end
    end
  end

  bw_stats_core #(.WINDOW_BASIS(bw_basis_t'(WINDOW_BASIS)),.WINDOW_WIDTH(WINDOW_WIDTH),
                  .UPDATE_STRIDE(UPDATE_STRIDE),.EPISODE_ENABLE(EPISODE_ENABLE),
                  .SILENCE_THRESHOLD(SILENCE_THRESHOLD),
                  .PHASE_ENABLE(PHASE_ENABLE),
                  .PHASE_N(PHASE_N),
                  .PHASE_MIN_SPAN(PHASE_MIN_SPAN),
                  .PHASE_K(PHASE_K),
                  .PHASE_STEADY_ENTER_ABS(PHASE_STEADY_ENTER_ABS),
                  .PHASE_STEADY_ENTER_REL(PHASE_STEADY_ENTER_REL),
                  .PHASE_STEADY_EXIT_ABS(PHASE_STEADY_EXIT_ABS),
                  .PHASE_STEADY_EXIT_REL(PHASE_STEADY_EXIT_REL),
                  .PHASE_RMS_ENTER_ABS(PHASE_RMS_ENTER_ABS),
                  .PHASE_RMS_ENTER_REL(PHASE_RMS_ENTER_REL),
                  .PHASE_RMS_EXIT_ABS(PHASE_RMS_EXIT_ABS),
                  .PHASE_RMS_EXIT_REL(PHASE_RMS_EXIT_REL),
                  .PHASE_TREND_ABS(PHASE_TREND_ABS),
                  .PHASE_TREND_REL(PHASE_TREND_REL)) core
    (.scope_id(scope_id),.scope_kind(scope_kind),.record(raw_record),.record_toggle(record_toggle),.stats_reset_n(reset_n),
     .progress_watermark_ticks(progress_watermark_ticks),.member_control(core_control),
     .member_control_toggle(core_control_toggle),.accepted_record_seq(accepted_record_seq),
     .accepted_control_count(accepted_control_count),.stats_epoch(stats_epoch),.result_seq(result_seq),
     .total_bytes(total_bytes),.total_events(total_events),.window_start_ticks(window_start_ticks),
     .window_end_ticks(window_end_ticks),.window_start_cycle(window_start_cycle),.window_end_cycle(window_end_cycle),
     .coverage_ticks(coverage_ticks),.coverage_cycles(coverage_cycles),.window_bytes(window_bytes),
     .window_events(window_events),.bandwidth_gbps(bandwidth_gbps),.bytes_per_cycle(bytes_per_cycle),
     .window_warmup(window_warmup),.window_full(window_full),.bytes_complete(bytes_complete),
     .events_complete(events_complete),.denominator_valid(denominator_valid),.window_valid(window_valid),
     .member_reset_coverage(member_reset_coverage),
     .episode_active(episode_active),.episode_status(episode_status),.episode_id(episode_id),
     .episode_result_seq(episode_result_seq),.episode_first_ticks(episode_first_ticks),
     .episode_last_ticks(episode_last_ticks),.episode_tail_ticks(episode_tail_ticks),
     .episode_confirmation_ticks(episode_confirmation_ticks),.episode_first_cycle(episode_first_cycle),
     .episode_last_cycle(episode_last_cycle),.episode_tail_cycle(episode_tail_cycle),
     .episode_bytes(episode_bytes),.episode_events(episode_events),.episode_duration_ticks(episode_duration_ticks),
     .episode_first_known(episode_first_known),.episode_last_known(episode_last_known),
     .episode_tail_known(episode_tail_known),.episode_bytes_complete(episode_bytes_complete),
     .episode_events_complete(episode_events_complete),.episode_member_reset_coverage(episode_member_reset_coverage),
     .episode_duration_valid(episode_duration_valid),.episode_e2e_valid(episode_e2e_valid),
     .episode_e2e_gbps(episode_e2e_gbps),.episode_result(episode_result),
     .phase_current(phase_current),
     .phase_candidate(phase_candidate),
     .phase_active(phase_active),
     .phase_eligible(phase_eligible),
     .phase_evidence_continuous(phase_evidence_continuous),
     .phase_evidence_sufficient(phase_evidence_sufficient),
     .phase_fit_valid(phase_fit_valid),
     .phase_id(phase_id),
     .phase_result_seq(phase_result_seq),
     .phase_window_seq(phase_window_seq),
     .phase_evidence_count(phase_evidence_count),
     .phase_evidence_span(phase_evidence_span),
     .phase_candidate_count(phase_candidate_count),
     .phase_candidate_ticks(phase_candidate_ticks),
     .phase_candidate_total_bytes(phase_candidate_total_bytes),
     .phase_candidate_total_events(phase_candidate_total_events),
     .phase_start_ticks(phase_start_ticks),
     .phase_confirmation_ticks(phase_confirmation_ticks),
     .phase_fit_mean(phase_fit_mean),
     .phase_fit_delta(phase_fit_delta),
     .phase_fit_rms(phase_fit_rms),
     .phase_result(phase_result));
endmodule

program bw_group_collector_scheduler;
  timeunit 1fs;timeprecision 1fs;
  initial bw_group_mon.collect_inputs();
endprogram
