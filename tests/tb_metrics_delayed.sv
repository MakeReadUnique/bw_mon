module tb_metrics_delayed;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("phase.delayed"),.WINDOW_WIDTH(100),.UPDATE_STRIDE(10),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(60),
    .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(20),.PHASE_K(4),
    .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
    .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
    .PHASE_RMS_ENTER_ABS(0.0),.PHASE_RMS_ENTER_REL(0.0),
    .PHASE_RMS_EXIT_ABS(0.0),.PHASE_RMS_EXIT_REL(0.0),
    .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes),.size_known(1'b1));
  initial begin
    wait(monitor_ready);
    for (int t=1;t<=196;t++) begin
      #(ns_to_ticks(t)-$time);valid=(t==95 || t==135);bytes=(t==95 ? 640 : 0);
      clk=1;#1;clk=0;
      if(t==120 && (point.phase_candidate!=BW_PHASE_STEADY || point.phase_candidate_count!=1 ||
          point.phase_candidate_ticks!=120000000 || point.phase_current!=BW_PHASE_UNDETERMINED ||
          point.phase_candidate_total_bytes!=640 || point.phase_candidate_total_events!=1))
        $fatal(1,"the first N-point candidate starts at120ns and snapshots raw640B");
      if(t==140 && (point.phase_current!=BW_PHASE_UNDETERMINED || point.phase_candidate_count!=3))
        $fatal(1,"K4 cannot confirm the stable phase after only three candidates");
      if(t==150 && (point.phase_current!=BW_PHASE_STEADY || point.phase_start_ticks!=120000000 ||
          point.phase_confirmation_ticks!=150000000 || !point.phase_active ||
          point.phase_evidence_count!=3 || $abs(point.phase_fit_mean-6.4)>1e-10 ||
          point.phase_fit_delta!=0.0 || point.phase_fit_rms!=0.0))
        $fatal(1,"phase confirmation150 must preserve candidate boundary120 after tail136");
    end
    if(point.phase_result_seq!=1 || point.phase_result.phase_kind!=BW_PHASE_STEADY ||
        point.phase_result.start_ticks!=120000000 || point.phase_result.end_ticks!=136000000 ||
        point.phase_result.confirmation_ticks!=150000000 || !point.phase_result.end_known ||
        point.phase_result.start_total_bytes!=640 || point.phase_result.end_total_bytes!=640 ||
        point.phase_result.start_total_events!=1 || point.phase_result.end_total_events!=2 ||
        point.episode_result_seq!=1 || !point.episode_result.e2e_valid ||
        $abs(point.episode_result.e2e_gbps-15.609756097560975)>1e-10)
      $fatal(1,"final phase clips to actual episode tail and preserves independent complete e2e");
    if(!point.phase_result.duration_valid || point.phase_result.duration_ticks!=16000000 ||
       !point.phase_result.bandwidth_valid || point.phase_result.byte_count!=0 ||
       point.phase_result.bandwidth_gbps!=0.0 || !point.phase_result.bytes_complete ||
       point.phase_result.variation.sample_count!=2 ||
       point.phase_result.variation.first_sample_ticks!=120000000 ||
       point.phase_result.variation.last_sample_ticks!=130000000 ||
       !point.phase_result.variation.stddev_valid || !point.phase_result.variation.cv_valid ||
       $abs(point.phase_result.variation.mean_gbps-6.4)>1e-10 ||
       point.phase_result.variation.stddev_gbps!=0.0 || point.phase_result.variation.cv_pct!=0.0 ||
       point.episode_result.variation.sample_count!=4 ||
       point.episode_result.variation.excluded_warmup!=0 ||
       !point.episode_result.last_steady_selection_valid ||
       point.episode_result.last_steady.phase_id!=point.phase_result.phase_id)
      $fatal(1,"clipped[120,136) raw BW0 must differ from two6.4 window samples; EP has four");
    $display("TB_PASS metrics_delayed");$finish;
  end
endmodule
