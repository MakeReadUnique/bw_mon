module bw_group_mon #(
  parameter string GROUP_ID="",
  parameter logic [1:0] WINDOW_BASIS=bw_mon_pkg::BW_NS,
  parameter logic [63:0] WINDOW_WIDTH=0,
  parameter logic [63:0] UPDATE_STRIDE=WINDOW_WIDTH,
  parameter logic [1:0] EPISODE_ENABLE = 0,
  parameter logic [63:0] SILENCE_THRESHOLD = bw_mon_pkg::BW_DEFAULT_SILENCE_THRESHOLD,
  parameter logic [1:0] PHASE_ENABLE = EPISODE_ENABLE
) (
  input logic clk,
  input logic reset_n
);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string scope_id,monitor_path;
  bw_scope_t scope_kind=BW_GROUP;
  `include "bw_scope_runtime.svh"
  // Effective public configuration after omission defaults are applied.
  bw_u64_t effective_stride,effective_silence;
  int group_handle,transport_source,direct_member_count,recursive_point_count;
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
  bit collector_stalled=0,collector_waiting=0,collector_recovery_pending=0;
  bw_u64_t collector_recovery_grant=0,collector_recovery_receipts=0;
  bw_u64_t controls_held=0,controls_published=0,controls_accepted=0,controls_acked=0;
  bw_u64_t expected_notice=0,expected_edge_index=0,last_expected_ticks=0;
  bit reset_observer_ready=0;
  localparam bit external_reset_capture=0;
  function void apply_captured_reset(logic value,bw_u64_t ticks);
`ifdef BW_MON_TEST_FAULTS
    if(monitor_ready && take_group_fault(scope_id,"reset_post"))return;
`endif
    core.enqueue_reset(value,ticks);
  endfunction
  `include "bw_reset_capture.svh"

  chandle clock_observer=null;
  import "DPI-C" context function chandle bw_native_watch_point_clock(input string scope_path);
  function void bw_native_point_edge();expect_group_edge(scope_id,$time);endfunction
  function automatic bit collector_ready_work();
    bw_control_frame_t candidate,control;
    int selected;
    selected=-1;candidate='0;
    for(int m=0;m<direct_member_count;m++)
      if(peek_member_control(group_handle,m,control) &&
         (selected<0 || control.value.timestamp_ticks<candidate.value.timestamp_ticks))begin
        selected=m;candidate=control;
      end
    if(selected>=0 && candidate.value.timestamp_ticks<=direct_source_watermark(group_handle) &&
       (expected_edges.size()==0 || candidate.value.timestamp_ticks<=expected_edges[0].timestamp_ticks))return 1;
    if(expected_edges.size()==0)return 0;
    return group_frame_inputs_ready(group_handle,expected_edges[0].edge_index,expected_edges[0].timestamp_ticks);
  endfunction
  function automatic void completion_stage_error(string stage,string detail);
    runtime_scope_error(BW_GROUP,scope_id,"GROUP_COMPLETION",$sformatf("stage=%s original_ticks=%0d expected_edge=%0d control_held=%0d control_published=%0d control_accepted=%0d control_acked=%0d reset_expected=%0d reset_captured=%0d reset_requested=%0d reset_received=%0d timer_requested=%0d timer_received=%0d recovery_grant=%0d recovery_received=%0d %s",stage,$time,group_batches[scope_id].expected,controls_held,controls_published,controls_accepted,controls_acked,group_batches[scope_id].reset_expected,group_batches[scope_id].reset_captured,core.reset_requests,core.reset_receipts,core.timer_requests,core.timer_receipts,collector_recovery_grant,collector_recovery_receipts,detail));
  endfunction
  function int bw_native_point_audit();
    bw_record_t unexpected;
    if(!monitor_ready || scope_failed(BW_GROUP,scope_id))return 0;
    if(group_batches[scope_id].grant>slot_settlement_generation ||
       core.settlement_required>slot_settlement_generation)return 1;
    // A parent depends on each actual producer's durable certificate. This
    // frozen DAG dependency is independent of native watcher callback order.
    if(group_producers_pending(group_handle))return 1;
`ifdef BW_MON_TEST_SCHEDULING
    if(bw_test_consumer_gates.exists(scope_id) && bw_test_consumer_gates[scope_id].paused &&
       (bw_test_consumer_gates[scope_id].resume_after_group!="" || bw_test_consumer_gates[scope_id].resume_after_groups.size()!=0))begin
      foreach(bw_test_consumer_gates[scope_id].resume_after_groups[d])begin
        if(!group_batches.exists(bw_test_consumer_gates[scope_id].resume_after_groups[d]))begin
          completion_stage_error("CONTINUATION","unknown dependency");return 0;
        end
        if(!scope_failed(BW_GROUP,bw_test_consumer_gates[scope_id].resume_after_groups[d]) && group_batches[bw_test_consumer_gates[scope_id].resume_after_groups[d]].acked<
           bw_test_consumer_gates[scope_id].resume_after_seq)return 1;
      end
      if(bw_test_consumer_gates[scope_id].resume_after_group!="" && !group_batches.exists(bw_test_consumer_gates[scope_id].resume_after_group))begin
        completion_stage_error("CONTINUATION","unknown dependency");return 0;
      end
      if(bw_test_consumer_gates[scope_id].resume_after_group!="" && !scope_failed(BW_GROUP,bw_test_consumer_gates[scope_id].resume_after_group) && group_batches[bw_test_consumer_gates[scope_id].resume_after_group].acked<
         bw_test_consumer_gates[scope_id].resume_after_seq)return 1;
      bw_test_consumer_gates[scope_id].paused=0;
      void'(request_slot_settlement(scope_id));
      return 1;
    end
`endif
    // Advisory wake loss does not erase durable ready work. Post one named
    // continuation, then require its receipt after its actual grant. Repeated
    // empty/quiet callbacks are never used as a completion certificate.
    if(collector_recovery_pending && collector_recovery_grant<=slot_settlement_generation)begin
      completion_stage_error("COLLECTOR_RECEIPT","posted recovery continuation did not run");return 0;
    end
    if(collector_waiting && collector_ready_work())begin
      if(!collector_recovery_pending)begin
        collector_recovery_pending=1;notify_group(group_handle);
        collector_recovery_grant=group_batches[scope_id].grant;
      end
      return 1;
    end
    if(group_batches[scope_id].reset_expected!=group_batches[scope_id].reset_captured)begin
      completion_stage_error("RESET_CAPTURE","missing captured raw reset");return 0;
    end
    if(group_batches[scope_id].reset_captured!=core.reset_requests)begin
      completion_stage_error("RESET_POST","captured reset missing core enqueue");return 0;
    end
    if(core.reset_requests!=core.reset_receipts)begin
      completion_stage_error("RESET_CORE","reset processing receipt missing");return 0;
    end
    if(core.timer_requests!=core.timer_receipts)begin
      completion_stage_error("TIMER_CORE","due timer processing receipt missing");return 0;
    end
    if(controls_held!=controls_published)begin
      completion_stage_error("CONTROL_PUBLICATION","held control missing durable output");return 0;
    end
    if(controls_held!=controls_accepted)begin
      completion_stage_error("CONTROL_CORE","local control receipt missing");return 0;
    end
    if(controls_held!=controls_acked)begin
      completion_stage_error("CONTROL_ACK","input control ACK missing");return 0;
    end
    close_group_batch(scope_id);
    if(scope_failed(BW_GROUP,scope_id))return 0;
    if(expected_edges.size()==0)for(int m=0;m<direct_member_count;m++)begin
      if(peek_member_frame(group_handle,m,unexpected))begin
        runtime_scope_error(BW_GROUP,scope_id,"GROUP_COMPLETION",$sformatf("stage=UNEXPECTED_FRAME source=%s original_ticks=%0d edge=%0d without actual group edge",source_name(member_source(group_handle,m)),unexpected.timestamp_ticks,unexpected.edge_index));return 0;
      end
    end
    if(expected_edges.size()!=0 || captured_resets.size()!=0 ||
       core.requested_actions!=core.consumed_actions || core.reset_requests!=core.reset_receipts ||
       core.timer_requests!=core.timer_receipts || !group_preparation_ready(group_handle) ||
       controls_held!=controls_published || controls_held!=controls_accepted || controls_held!=controls_acked)
      completion_stage_error("POSTED_ACTION","missing control/core/input receipt");
    if(!scope_failed(BW_GROUP,scope_id) && WINDOW_BASIS==BW_NS && core.reset_applied && core.current_reset_n!==1'b0 &&
       ((core.next_update_ticks<=$time && core.next_update_ticks<=progress_watermark_ticks) ||
        (core.scheduled_episode_deadline_valid && core.scheduled_episode_deadline<=$time && core.scheduled_episode_deadline<=progress_watermark_ticks)))
      completion_stage_error("DUE_TIMER","no due timer receipt or continuation");
    return 0;
  endfunction
  export "DPI-C" function bw_native_point_edge;
  export "DPI-C" function bw_native_point_audit;

  initial begin
    core.use_external_reset_capture();
    monitor_path=$sformatf("%m");scope_id=GROUP_ID;
    effective_stride=UPDATE_STRIDE;
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
    validate_phase_config(PHASE_ENABLE,EPISODE_ENABLE,WINDOW_BASIS,scope_id);
    initialize_reset_capture(monitor_path,"reset_n");
    group_handle=register_group_owner(scope_id,monitor_path,bw_basis_t'(WINDOW_BASIS),
                                      WINDOW_WIDTH,effective_stride);
    transport_source=group_source_handle(group_handle);
    register_group_completion(scope_id);
    clock_observer=bw_native_watch_point_clock(monitor_path);
    if(clock_observer==null)core_error("SLOT_SCHEDULER",scope_id,"cannot register independent group raw-clock observer");
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
    wait(core.scope_id==scope_id);
    reset_observer_ready=1;bw_native_reset_snapshot(reset_capture_handle);
    wait(core.reset_applied);
    begin : prepare_inputs
      bw_notification notice;
      bw_u64_t seen;
      notice=group_notification(group_handle);
      forever begin
        seen=notice.seq;
        if(group_preparation_ready(group_handle))break;
        wait(notice.seq!=seen);
      end
    end
    wait(core.consumed_actions==core.requested_actions && captured_resets.size()==0);
    note_scope_prepared(transport_source);
    wait(monitor_ready);
  end
  initial begin : cancel_disabled_work
    wait(monitor_ready);
    forever begin
      if(scope_failed(BW_GROUP,scope_id))begin
        expected_edges.delete();captured_resets.delete();
        collector_recovery_pending=0;collector_waiting=0;
        core.cancel_runtime_work();
        break;
      end
      @(monitoring_failure_count or monitoring_shared_disabled);
    end
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
    if (monitor_ready && $time>measurement_start_ticks && !scope_failed(BW_GROUP,scope_id)) begin
`ifdef BW_MON_TEST_FAULTS
      if(take_group_fault(scope_id,"capture"))disable capture_expected_edge;
`endif
      check_monitor_time($time,scope_id);
      if(runtime_failed())disable capture_expected_edge;
      if (expected_edge_index!=0 && $time<=last_expected_ticks)
        core_error("GROUP_CLOCK",scope_id,"actual sampling timestamps must strictly increase");
      if(runtime_failed())disable capture_expected_edge;
      expected_edge_index=checked_add(expected_edge_index,1,scope_id);
      if(runtime_failed())disable capture_expected_edge;
      last_expected_ticks=$time;
      expected.timestamp_ticks=$time;expected.edge_index=expected_edge_index;
      check_storage_growth(expected_edges.size(),scope_id,"group.expected",expected.timestamp_ticks,expected.edge_index,expected.edge_index);
      if(runtime_failed())disable capture_expected_edge;
      expected_edges.push_back(expected);
      group_batches[scope_id].captured=expected.edge_index;
      void'(request_slot_settlement(scope_id));
      expected_notice=checked_add(expected_notice,1,scope_id);refresh_progress();
    end
  end

  task automatic commit_control(int member_index,bw_control_frame_t envelope);
    bw_u64_t receipt;
    if(runtime_failed())return;
    controls_held=checked_add(controls_held,1,scope_id);
    receipt=checked_add(accepted_control_count,1,scope_id);
    if(runtime_failed())return;
`ifdef BW_MON_TEST_FAULTS
    if(take_group_fault(scope_id,"control_publication"))begin collector_stalled=1;return;end
`endif
    publish_control(transport_source,envelope.value);
    if(runtime_failed())return;
    controls_published=controls_held;
    raw_control=envelope.value;control_result_seq=checked_add(control_result_seq,1,scope_id);
    if(runtime_failed())return;
    control_toggle<=!control_toggle;
    core_control=envelope.value;
`ifdef BW_MON_TEST_FAULTS
    if(!take_group_fault(scope_id,"control_core"))core_control_toggle<=!core_control_toggle;
`else
    core_control_toggle<=!core_control_toggle;
`endif
    wait(accepted_control_count>=receipt || scope_failed(BW_GROUP,scope_id));
    if(scope_failed(BW_GROUP,scope_id))return;
    controls_accepted=controls_held;
`ifdef BW_MON_TEST_FAULTS
    if(take_group_fault(scope_id,"control_ack"))begin collector_stalled=1;return;end
`endif
    acknowledge_member_control(group_handle,member_index,envelope.transport_seq);
    if(runtime_failed())return;
    controls_acked=controls_held;
    refresh_progress();
  endtask

  task automatic commit_frame(expected_edge_t expected);
    bw_record_t member,frame;
    expected_edge_t discarded;
    if(runtime_failed())return;
`ifdef BW_MON_TEST_FAULTS
    if(take_group_fault(scope_id,"held"))begin collector_stalled=1;return;end
`endif
    group_batches[scope_id].held=expected.edge_index;
    frame='0;frame.timestamp_ticks=expected.timestamp_ticks;frame.edge_index=expected.edge_index;
    frame.record_seq=checked_add(raw_sequence,1,scope_id);
    if(runtime_failed())return;
    frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1'b1;
    for (int m=0;m<direct_member_count;m++) begin
      if (!peek_member_frame(group_handle,m,member))
        core_error("COLLECTOR_STATE",scope_id,"complete input disappeared before commit");
      if(runtime_failed())return;
      frame.byte_inc=checked_add(frame.byte_inc,member.byte_inc,scope_id);
      if(runtime_failed())return;
      frame.event_inc=checked_add(frame.event_inc,member.event_inc,scope_id);
      if(runtime_failed())return;
      frame.reset_points=checked_add(frame.reset_points,member.reset_points,scope_id);
      if(runtime_failed())return;
      frame.bytes_complete&=member.bytes_complete;frame.events_complete&=member.events_complete;
    end
    raw_sequence=frame.record_seq;raw_record=frame;
`ifdef BW_MON_TEST_FAULTS
    if(take_group_fault(scope_id,"publication"))begin collector_stalled=1;return;end
`endif
    publish_frame(transport_source,frame);
    if(runtime_failed())return;
    group_batches[scope_id].published=frame.record_seq;
`ifdef BW_MON_TEST_FAULTS
    if(!take_group_fault(scope_id,"core"))record_toggle<=!record_toggle;
`else
    record_toggle<=!record_toggle;
`endif
    wait(accepted_record_seq>=frame.record_seq || scope_failed(BW_GROUP,scope_id));
    if(scope_failed(BW_GROUP,scope_id))return;
    group_core_receipt(scope_id,frame.record_seq);
`ifdef BW_MON_TEST_FAULTS
    if(take_group_fault(scope_id,"ack"))begin collector_stalled=1;return;end
`endif
    for (int m=0;m<direct_member_count;m++)begin
      acknowledge_member_frame(group_handle,m,frame.record_seq);
      if(runtime_failed())return;
    end
    group_batches[scope_id].acked=frame.record_seq;
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
      if(scope_failed(BW_GROUP,scope_id))return;
`ifdef BW_MON_TEST_SCHEDULING
      wait(!test_gate.paused || scope_failed(BW_GROUP,scope_id));
      if(runtime_failed())return;
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
        commit_control(selected_control,candidate);if(collector_stalled)return;continue;
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
      if(runtime_failed())return;
      if (all_frames && expected_edges[0].timestamp_ticks<=direct_source_watermark(group_handle)) begin
        commit_frame(expected_edges[0]);if(collector_stalled)return;continue;
      end
      collector_waiting=1;
      wait(notice.seq!=seen_notice || expected_notice!=seen_expected || scope_failed(BW_GROUP,scope_id));
      collector_waiting=0;
      if(runtime_failed())return;
      if(collector_recovery_pending)begin
`ifdef BW_MON_TEST_FAULTS
        if(take_group_fault(scope_id,"collector_recovery"))return;
`endif
        collector_recovery_receipts=checked_add(collector_recovery_receipts,1,scope_id);
        if(runtime_failed())return;
        collector_recovery_pending=0;
      end
    end
  endtask

  bw_group_collector_scheduler collector();

  bw_stats_core #(.WINDOW_BASIS(bw_basis_t'(WINDOW_BASIS)),.WINDOW_WIDTH(WINDOW_WIDTH),
                  .UPDATE_STRIDE(UPDATE_STRIDE),.EPISODE_ENABLE(EPISODE_ENABLE),
                  .SILENCE_THRESHOLD(SILENCE_THRESHOLD),
                  .PHASE_ENABLE(PHASE_ENABLE)) core
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
     .phase_reason(phase_reason),.phase_evidence_required(phase_evidence_required),
                  .phase_candidate_required(phase_candidate_required),.phase_minimum_span(phase_minimum_span),
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
     .phase_fit_rms(phase_fit_rms),.phase_fit_trend_rms(phase_fit_trend_rms),
     .phase_result(phase_result));
endmodule

program bw_group_collector_scheduler;
  timeunit 1fs;timeprecision 1fs;
  initial bw_group_mon.collect_inputs();
endprogram
