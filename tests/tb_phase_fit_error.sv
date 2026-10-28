module tb_phase_fit_error;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.fit_error"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(10),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(20),.PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
    .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(1e308),
    .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(1e308),
    .PHASE_RMS_ENTER_ABS(0.0),.PHASE_RMS_ENTER_REL(0.0),
    .PHASE_RMS_EXIT_ABS(0.0),.PHASE_RMS_EXIT_REL(0.0),
    .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(1e308)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=5;t++)begin #(ns_to_ticks(t)-$time);clk=1;#1;clk=0;end
    $fatal(1,"expected core error did not occur");
  end
endmodule
