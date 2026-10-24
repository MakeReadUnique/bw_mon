module tb_protocol_config_error;
  timeunit 1ns; timeprecision 1fs;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(bw_mon_pkg::bw_protocol_t'(3)),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  initial begin #1ns;$fatal(1,"expected core error did not occur");end
endmodule
