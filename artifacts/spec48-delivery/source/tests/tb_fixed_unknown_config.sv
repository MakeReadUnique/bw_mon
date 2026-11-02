module tb_fixed_unknown_config;
  timeunit 1ns;timeprecision 1fs;
  bw_mon_setup setup();
  bw_point_mon #(.FIXED_BYTES(64'bx),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) point
    (.clk(1'b0),.reset_n(1'b1));
  initial begin #1ns;$fatal(1,"expected core error did not occur");end
endmodule
