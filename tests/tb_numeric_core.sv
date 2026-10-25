module tb_numeric_core;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string mode;
  int handle;
  logic kind=BW_GROUP;
  logic [63:0] progress=BW_U64_MAX;
  bw_record_t frame='0;
  bw_control_t control='0;
  bit toggle=0,control_toggle=0;
  bw_u64_t accepted,controls,total,events,window_bytes,results;
  bit bytes_complete,events_complete,window_valid;
  bw_stats_core #(.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) core
    (.scope_id("numeric.core"),
     .scope_kind(kind),
     .record(frame),
     .record_toggle(toggle),
     .stats_reset_n(1'b1),
     .member_control(control),
     .member_control_toggle(control_toggle),
     .progress_watermark_ticks(progress),
     .accepted_record_seq(accepted),
     .accepted_control_count(controls),
     .stats_epoch(),
     .result_seq(results),
     .total_bytes(total),
     .total_events(events),
     .window_start_ticks(),
     .window_end_ticks(),
     .window_start_cycle(),
     .window_end_cycle(),
     .coverage_ticks(),
     .coverage_cycles(),
     .window_bytes(window_bytes),
     .window_events(),
     .bandwidth_gbps(),
     .bytes_per_cycle(),
     .window_warmup(),
     .window_full(),
     .bytes_complete(bytes_complete),
     .events_complete(events_complete),
     .denominator_valid(),
     .window_valid(window_valid),
     .member_reset_coverage(),
     .episode_active(),
     .episode_status(),
     .episode_id(),
     .episode_result_seq(),
     .episode_first_ticks(),
     .episode_last_ticks(),
     .episode_tail_ticks(),
     .episode_confirmation_ticks(),
     .episode_first_cycle(),
     .episode_last_cycle(),
     .episode_tail_cycle(),
     .episode_bytes(),
     .episode_events(),
     .episode_duration_ticks(),
     .episode_first_known(),
     .episode_last_known(),
     .episode_tail_known(),
     .episode_bytes_complete(),
     .episode_events_complete(),
     .episode_member_reset_coverage(),
     .episode_duration_valid(),
     .episode_e2e_valid(),
     .episode_e2e_gbps(),
     .episode_result(),
     .phase_current(),
     .phase_candidate(),
     .phase_active(),
     .phase_eligible(),
     .phase_evidence_continuous(),
     .phase_evidence_sufficient(),
     .phase_fit_valid(),
     .phase_id(),
     .phase_result_seq(),
     .phase_window_seq(),
     .phase_evidence_count(),
     .phase_evidence_span(),
     .phase_candidate_count(),
     .phase_candidate_ticks(),
     .phase_candidate_total_bytes(),
     .phase_candidate_total_events(),
     .phase_start_ticks(),
     .phase_confirmation_ticks(),
     .phase_fit_mean(),
     .phase_fit_delta(),
     .phase_fit_rms(),
     .phase_result());
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="frame_bytes";
    handle=register_point("registry.p0","component0",BW_NS,1,1,"clk");
    handle=register_point("registry.p1","component1",BW_NS,1,1,"clk");configure_monitor(2);wait(monitor_ready);
    #125000;
    if(mode=="kind")kind=1'bx;
    if(mode=="progress")progress=64'hx000000000000000;
    #125000;
    frame='0;frame.timestamp_ticks=$time;frame.record_seq=1;frame.edge_index=1;
    frame.byte_inc=17;frame.event_inc=1;frame.reset_n=1;
    control='0;control.timestamp_ticks=$time;control.control_seq=1;control.reset_n=1'bz;
    if(mode=="frame_bytes")frame.byte_inc=64'hx000000000000011;
    if(mode=="frame_time")frame.timestamp_ticks=64'hx00000000003d090;
    if(mode=="control_sequence")begin control.control_seq=64'hx000000000000001;control_toggle<=1;end
    else toggle<=1;
    #1;
    if(mode=="known_partial")begin
      control_toggle<=1;#1000000;
      if(total!=17 || events!=1 || accepted!=1 || controls!=1 || window_bytes!=17 || results!=1 ||
         bytes_complete || events_complete || window_valid)
        $fatal(1,"known partial raw sums and X/Z reset quality must remain legitimate normalized input");
      $display("TB_PASS numeric_core known_partial");$finish;
    end
    $fatal(1,"expected core error did not occur");
  end
endmodule
