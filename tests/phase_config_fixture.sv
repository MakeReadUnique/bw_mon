module phase_config_fixture #(parameter int CASE=0);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.config"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(10),
    .EPISODE_ENABLE(CASE!=9),.SILENCE_THRESHOLD(2),.PHASE_ENABLE(1),
    .PHASE_N(CASE==1 ? 64'd2 : CASE==8 ? 64'd2147483648 : CASE==11 ? 64'bx : 64'd3),
    .PHASE_MIN_SPAN(CASE==2 ? 0 : 2),.PHASE_K(CASE==3 ? 0 : 1),
    .PHASE_STEADY_ENTER_ABS(0.2),.PHASE_STEADY_ENTER_REL(0.0),
    .PHASE_STEADY_EXIT_ABS(CASE==5 ? 0.1 : 0.3),.PHASE_STEADY_EXIT_REL(0.0),
    .PHASE_RMS_ENTER_ABS(CASE==4 ? -0.1 : CASE==10 ? -1.0 : 0.1),.PHASE_RMS_ENTER_REL(0.0),
    .PHASE_RMS_EXIT_ABS(0.2),.PHASE_RMS_EXIT_REL(0.0),
    .PHASE_TREND_ABS(CASE==6 ? 0.3 : CASE==12 ? (1e300*1e300) : 1.0),
    .PHASE_TREND_REL(CASE==7 ? ((1e300*1e300)-(1e300*1e300)) : 0.0)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  initial begin
    #1000000;
    if(CASE!=0)$fatal(1,"expected core error did not occur");
    if(!monitor_ready)$fatal(1,"fully explicit valid phase settings did not start");
    $display("TB_PASS phase_config_valid");$finish;
  end
endmodule
