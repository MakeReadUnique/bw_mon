module tb_phase_zero;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(5)) setup();
  for(genvar g=0;g<5;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("phase.zero%0d",g)),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(0),
      .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2),.PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(g==3 ? 3 : 2),.PHASE_K(g==1 ? 5 : g==4 ? 4 : 1),
      .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
      .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
      .PHASE_RMS_ENTER_ABS(0.0),.PHASE_RMS_ENTER_REL(0.0),
      .PHASE_RMS_EXIT_ABS(0.0),.PHASE_RMS_EXIT_REL(0.0),
      .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) point
      (.clk(clk),.reset_n(1'b1),.valid(g==2 ? 1'b0 : valid));
  end
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=7;t++)begin
      #(ns_to_ticks(t)-$time);valid=t<=4;clk=1;#1;clk=0;
      if(t==4 && (scopes[0].point.phase_current!=BW_PHASE_STEADY ||
          scopes[0].point.phase_fit_mean!=0.0 || scopes[0].point.phase_fit_delta!=0.0 ||
          scopes[0].point.phase_fit_rms!=0.0 || scopes[1].point.phase_candidate_count!=1 ||
          scopes[3].point.phase_evidence_count!=3 || scopes[3].point.phase_evidence_sufficient ||
          scopes[3].point.phase_fit_valid || scopes[3].point.phase_current!=BW_PHASE_UNDETERMINED))
        $fatal(1,"a zero-mean bandwidth line can be steady while K confirmation remains independent");
    end
    if(scopes[0].point.phase_result_seq!=1 || scopes[0].point.phase_result.start_ticks!=4000000 ||
       scopes[0].point.phase_result.end_ticks!=5000000 || scopes[0].point.phase_result.start_total_events!=3 ||
       scopes[0].point.phase_result.end_total_events!=4 || !scopes[0].point.episode_result.e2e_valid ||
       scopes[0].point.episode_result.e2e_gbps!=0.0 || scopes[1].point.phase_result_seq!=0 ||
       !scopes[1].point.episode_result.e2e_valid || scopes[1].point.episode_result.e2e_gbps!=0.0 ||
       scopes[2].point.phase_id!=0 || scopes[2].point.phase_result_seq!=0 || scopes[2].point.episode_id!=0 ||
       scopes[3].point.phase_result_seq!=0 || !scopes[3].point.episode_result.e2e_valid ||
       scopes[4].point.phase_result_seq!=1 || scopes[4].point.phase_result.start_ticks!=4000000 ||
       scopes[4].point.phase_result.end_ticks!=5000000 || scopes[4].point.phase_result.confirmation_ticks!=7000000)
      $fatal(1,"unconfirmed phases and no-activity scopes cannot become fake final stages or invalidate complete zero e2e");
    $display("TB_PASS phase_zero");$finish;
  end
endmodule
