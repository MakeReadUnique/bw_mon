module tb_phase_reset;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("phase.reset"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(10),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5),.PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
    .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
    .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
    .PHASE_RMS_ENTER_ABS(0.0),.PHASE_RMS_ENTER_REL(0.0),
    .PHASE_RMS_EXIT_ABS(0.0),.PHASE_RMS_EXIT_REL(0.0),
    .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) point
    (.clk(clk),.reset_n(reset_n),.valid(1'b1));
  initial begin
    wait(monitor_ready);
    for(int n=0;n<11;n++)begin #(250000+ns_to_ticks(n)-$time);clk=1;#1;clk=0;end
  end
  initial begin
    wait(monitor_ready);#5500000;reset_n=0;#1;
    if(point.stats_epoch!=1 || point.phase_active || point.phase_current!=BW_PHASE_UNDETERMINED ||
       point.phase_eligible || point.phase_evidence_count!=0 || point.phase_candidate_count!=0 ||
       point.phase_start_ticks!=0 || point.phase_confirmation_ticks!=0 || point.phase_result_seq!=1 ||
       point.phase_result.end_known)
      $fatal(1,"own reset clears current phase/evidence and retains the old final fragment without stale scalar identity");
    #999999;reset_n=1;
    #(7500001-$time);
    if(!point.window_full || !point.phase_eligible || point.phase_evidence_count!=1 ||
       point.phase_current!=BW_PHASE_UNDETERMINED || point.phase_result.stats_epoch!=0)
      $fatal(1,"history and retired activity clear with reset while the old immutable result keeps its epoch");
    #(9500001-$time);
    if(point.phase_current!=BW_PHASE_STEADY || point.phase_start_ticks!=9500000 ||
       point.phase_confirmation_ticks!=9500000 || point.phase_id!=2 || point.episode_id!=2)
      $fatal(1,"the new statistics epoch must accumulate fresh evidence before confirming its own phase");
    $display("TB_PASS phase_reset");$finish;
  end
endmodule
