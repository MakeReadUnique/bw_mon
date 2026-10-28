module tb_hint_zero_threshold;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_CYCLE),.SHORTAGE_THRESHOLD(0)) point(.clk(1'b0),.reset_n(1'b1));
  initial begin #1000000;$fatal(1,"expected core error did not occur");end
endmodule
