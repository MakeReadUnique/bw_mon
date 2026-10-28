module tb_metrics_controls;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  logic [1:0] reset_n=2'b11;
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_phase_result_t phase_result;
    bw_episode_result_t episode_result;
    bw_point_mon #(.POINT_ID($sformatf("metrics.source%0d",g)),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
      .FIXED_BYTES(10)) point(.clk(clk),.reset_n(reset_n[g]),.valid(valid));
    bw_stats_core #(.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4),
      .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
      .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
      .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
      .PHASE_RMS_ENTER_ABS(0.0),.PHASE_RMS_ENTER_REL(0.0),
      .PHASE_RMS_EXIT_ABS(0.0),.PHASE_RMS_EXIT_REL(0.0),
      .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) ancestor
      (.scope_id($sformatf("metrics.ancestor%0d",g)),.scope_kind(BW_GROUP),
       .record(point.raw_record),.record_toggle(point.record_toggle),.stats_reset_n(1'b1),
       .member_control(point.raw_control),.member_control_toggle(point.control_toggle),
       .phase_result(phase_result),.episode_result(episode_result),
       .progress_watermark_ticks(BW_U64_MAX),.accepted_record_seq(),.accepted_control_count(),
       .stats_epoch(),.result_seq(),.total_bytes(),
       .total_events(),.window_start_ticks(),.window_end_ticks(),
       .window_start_cycle(),.window_end_cycle(),.coverage_ticks(),
       .coverage_cycles(),.window_bytes(),.window_events(),
       .bandwidth_gbps(),.bytes_per_cycle(),.window_warmup(),
       .window_full(),.bytes_complete(),.events_complete(),
       .denominator_valid(),.window_valid(),.member_reset_coverage(),
       .episode_active(),.episode_status(),.episode_id(),
       .episode_result_seq(),.episode_first_ticks(),.episode_last_ticks(),
       .episode_tail_ticks(),.episode_confirmation_ticks(),.episode_first_cycle(),
       .episode_last_cycle(),.episode_tail_cycle(),.episode_bytes(),
       .episode_events(),.episode_duration_ticks(),.episode_first_known(),
       .episode_last_known(),.episode_tail_known(),.episode_bytes_complete(),
       .episode_events_complete(),.episode_member_reset_coverage(),.episode_duration_valid(),
       .episode_e2e_valid(),.episode_e2e_gbps(),.phase_current(),
       .phase_candidate(),.phase_active(),.phase_eligible(),
       .phase_evidence_continuous(),.phase_evidence_sufficient(),.phase_fit_valid(),
       .phase_id(),.phase_result_seq(),.phase_window_seq(),
       .phase_evidence_count(),.phase_evidence_span(),.phase_candidate_count(),
       .phase_candidate_ticks(),.phase_candidate_total_bytes(),.phase_candidate_total_events(),
       .phase_start_ticks(),.phase_confirmation_ticks(),.phase_fit_mean(),
       .phase_fit_delta(),.phase_fit_rms());
  end
  initial begin
    wait(monitor_ready);
    for(int t=0;t<=12;t++)begin
      #(250000+ns_to_ticks(t)-$time);valid=t<12;clk=1;#1;clk=0;
      if(t==7 && (scopes[0].phase_result.start_ticks!=3000001 || scopes[0].phase_result.end_ticks!=7000001 ||
         !scopes[0].phase_result.duration_valid || scopes[0].phase_result.duration_ticks!=4000000 ||
         scopes[0].phase_result.bytes_complete || scopes[0].phase_result.events_complete ||
         scopes[0].phase_result.bandwidth_valid || !scopes[0].phase_result.variation.stddev_valid ||
         scopes[0].phase_result.variation.sample_count!=4 || scopes[0].phase_result.variation.mean_gbps!=10.0 ||
         scopes[0].phase_result.end_unknown_ticks-scopes[0].phase_result.start_unknown_ticks!=100000))
        $fatal(1,"no-edge unknown member interval independently invalidates raw bytes while earlier selected windows/duration stay complete");
    end
    #(17000003-$time);
    if(!scopes[0].phase_result.bytes_complete || !scopes[0].phase_result.bandwidth_valid ||
       scopes[0].phase_result.start_ticks!=10000001 || scopes[0].phase_result.end_ticks!=12250001 ||
       scopes[0].episode_result.e2e_valid || scopes[0].episode_result.variation.stddev_valid ||
       scopes[0].episode_result.variation.unknown_samples!=1 ||
       !scopes[1].episode_result.e2e_valid || !scopes[1].episode_result.variation.stddev_valid ||
       !scopes[1].phase_result.bytes_complete || !scopes[1].phase_result.member_reset_coverage ||
       !scopes[1].episode_result.member_reset_coverage || scopes[1].phase_result.bandwidth_valid==0)
      $fatal(1,"a later independently complete stage survives unknowns, while known member reset records coverage without invalidating metrics");
    $display("TB_PASS metrics_controls");$finish;
  end
  initial begin
    wait(monitor_ready);#6100000;reset_n[0]=1'bx;reset_n[1]=0;
    #100000;reset_n=2'b11;
  end
endmodule
