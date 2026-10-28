module tb_member_control_error;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_control_t control;
  bit control_toggle=0;
  int handle;
  bit invalid_point=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_stats_core #(.WINDOW_WIDTH(2), .UPDATE_STRIDE(1)) core
    (.scope_id("control.scope"), .record('0), .record_toggle(1'b0),
     .member_control(control), .member_control_toggle(control_toggle),.stats_reset_n(1'b1),
     .accepted_record_seq(),.accepted_control_count(),.stats_epoch(),.result_seq(),
     .total_bytes(),.total_events(),.window_start_ticks(),.window_end_ticks(),
     .window_start_cycle(),.window_end_cycle(),.coverage_ticks(),.coverage_cycles(),
     .window_bytes(),.window_events(),.bandwidth_gbps(),.bytes_per_cycle(),
     .window_warmup(),.window_full(),.bytes_complete(),.events_complete(),
     .denominator_valid(),.window_valid(),.member_reset_coverage(),
     .scope_kind(BW_POINT),.progress_watermark_ticks(BW_U64_MAX),.episode_active(),
     .episode_status(),.episode_id(),.episode_result_seq(),
     .episode_first_ticks(),.episode_last_ticks(),.episode_tail_ticks(),
     .episode_confirmation_ticks(),.episode_first_cycle(),.episode_last_cycle(),
     .episode_tail_cycle(),.episode_bytes(),.episode_events(),
     .episode_duration_ticks(),.episode_first_known(),.episode_last_known(),
     .episode_tail_known(),.episode_bytes_complete(),.episode_events_complete(),
     .episode_member_reset_coverage(),.episode_duration_valid(),.episode_e2e_valid(),
     .episode_e2e_gbps(),.episode_result(),
     .phase_current(),.phase_candidate(),.phase_active(),
     .phase_eligible(),.phase_evidence_continuous(),.phase_evidence_sufficient(),
     .phase_fit_valid(),.phase_id(),.phase_result_seq(),
     .phase_window_seq(),.phase_evidence_count(),.phase_evidence_span(),
     .phase_candidate_count(),.phase_candidate_ticks(),.phase_candidate_total_bytes(),
     .phase_candidate_total_events(),.phase_start_ticks(),.phase_confirmation_ticks(),
     .phase_fit_mean(),.phase_fit_delta(),.phase_fit_rms(),
     .phase_result());
  initial begin
    handle=register_point("origin.point","tb_member_control_error",BW_NS,2,1);
    void'($value$plusargs("INVALID_POINT=%d",invalid_point));
    wait(monitor_ready);
    #1000000;
    control='0;
    control.timestamp_ticks=$time; control.point_handle=invalid_point ? handle+1 : handle;
    control.control_seq=1; control.reset_n=1;
    control_toggle<=!control_toggle;
    #1000000;
    control.timestamp_ticks=$time;
    control_toggle<=!control_toggle;
    #1; $fatal(1,"expected core error did not occur");
  end
endmodule
