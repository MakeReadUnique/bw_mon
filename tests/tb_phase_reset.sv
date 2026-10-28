module tb_phase_reset;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.reset"),.WINDOW_WIDTH(1),.FIXED_BYTES(10),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(reset_n),.valid(1'b1));
  initial begin
    wait(monitor_ready);
    for(int n=0;n<21;n++)begin #(measurement_start_ticks+250000+ns_to_ticks(n)-$time);clk=1;#1;clk=0;end
  end
  initial begin
    wait(monitor_ready);#10500000;reset_n=0;#1;
    if(point.stats_epoch!=1 || point.phase_active || point.phase_current!=BW_PHASE_UNDETERMINED ||
       point.phase_eligible || point.phase_evidence_count!=0 || point.phase_candidate_count!=0 ||
       point.phase_start_ticks!=0 || point.phase_confirmation_ticks!=0 || point.phase_result_seq!=1 ||
       point.phase_result.end_known || point.phase_result.stats_epoch!=0)
      $fatal(1,"own reset clears current evidence while retaining the prior immutable fragment and epoch");
    #999999;reset_n=1;
    #(measurement_start_ticks+12500002-$time);
    if(!point.window_full || !point.phase_eligible || point.phase_evidence_count!=1 ||
       point.phase_current!=BW_PHASE_UNDETERMINED || point.phase_result.stats_epoch!=0)
      $fatal(1,"post-reset window history begins a fresh six-observation chain");
    #(measurement_start_ticks+18500002-$time);
    if(point.phase_current!=BW_PHASE_STEADY || point.phase_start_ticks!=measurement_start_ticks+17500000 ||
       point.phase_confirmation_ticks!=measurement_start_ticks+18500000 || point.phase_id!=2 || point.episode_id!=2)
      $fatal(1,"new epoch confirms only its own fresh candidate chain");
    $display("TB_PASS phase_reset");$finish;
  end
endmodule
