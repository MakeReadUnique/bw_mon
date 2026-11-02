module tb_numeric_dynamic_policy;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("dynamic.subject"),.FIXED_BYTES(0),.DYNAMIC_BYTES(2'b0x),
    .WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) point_mon
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.size_bytes(64'd64),.size_known(1'b1));
  initial begin #250000;clk=1;#1;$fatal(1,"expected core error did not occur");end
endmodule
