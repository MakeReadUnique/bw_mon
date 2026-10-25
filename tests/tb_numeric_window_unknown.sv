module tb_numeric_window_unknown;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("window.subject"),.FIXED_BYTES(1),.WINDOW_WIDTH(64'hx000000000000001),.UPDATE_STRIDE(1)) point_mon
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  initial begin #1;$fatal(1,"expected core error did not occur");end
endmodule
