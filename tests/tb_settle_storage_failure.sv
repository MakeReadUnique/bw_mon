module tb_settle_storage_failure;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string scope_id="";
  int mode=0,handle;
  bw_mon_setup setup();
  bw_stats_core #(.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) core
    (.scope_id(scope_id),.record('0),.record_toggle(1'b0),
     .accepted_record_seq(),.result_seq(),.episode_result_seq(),
     .episode_active(),.episode_tail_ticks(),.episode_tail_known(),
     .episode_result(),
     .scope_kind(BW_POINT),.stats_reset_n(1'b1),.progress_watermark_ticks(BW_U64_MAX),
     .member_control('0),.member_control_toggle(1'b0),.accepted_control_count(),
     .stats_epoch(),.total_bytes(),.total_events(),
     .window_start_ticks(),.window_end_ticks(),.window_start_cycle(),
     .window_end_cycle(),.coverage_ticks(),.coverage_cycles(),
     .window_bytes(),.window_events(),.bandwidth_gbps(),
     .bytes_per_cycle(),.window_warmup(),.window_full(),
     .bytes_complete(),.events_complete(),.denominator_valid(),
     .window_valid(),.member_reset_coverage(),.episode_status(),
     .episode_id(),.episode_first_ticks(),.episode_last_ticks(),
     .episode_confirmation_ticks(),.episode_first_cycle(),.episode_last_cycle(),
     .episode_tail_cycle(),.episode_bytes(),.episode_events(),
     .episode_duration_ticks(),.episode_first_known(),.episode_last_known(),
     .episode_bytes_complete(),.episode_events_complete(),.episode_member_reset_coverage(),
     .episode_duration_valid(),.episode_e2e_valid(),.episode_e2e_gbps(),
     .phase_current(),.phase_candidate(),.phase_active(),
     .phase_eligible(),.phase_evidence_continuous(),.phase_evidence_sufficient(),
     .phase_fit_valid(),.phase_id(),.phase_result_seq(),
     .phase_window_seq(),.phase_evidence_count(),.phase_evidence_span(),
     .phase_candidate_count(),.phase_candidate_ticks(),.phase_candidate_total_bytes(),
     .phase_candidate_total_events(),.phase_start_ticks(),.phase_confirmation_ticks(),
     .phase_fit_mean(),.phase_fit_delta(),.phase_fit_rms(),
     .phase_result());
  initial begin
    void'($value$plusargs("MODE=%d",mode));
    if(mode==0)bw_native_fail_reset_allocation();
    else inject_growth_failure("native.observer","scheduler.reset_capture");
    handle=register_point("native.observer","tb_settle_storage_failure.core",BW_NS,2,1);
    scope_id="native.observer";
    #1;$fatal(1,"expected core error did not occur");
  end
endmodule
