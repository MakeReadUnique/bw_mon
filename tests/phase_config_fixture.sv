module phase_config_fixture #(parameter int CASE=0);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.config"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(10),
    .EPISODE_ENABLE(CASE!=9),.SILENCE_THRESHOLD(2),.PHASE_ENABLE(CASE==11 ? 2'bxx : 2'd1)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  initial begin
    #1000000;
    if(CASE!=0)$fatal(1,"expected core error did not occur");
    if(!monitor_ready)$fatal(1,"fully explicit valid phase settings did not start");
    $display("TB_PASS phase_config_valid");$finish;
  end
endmodule
