module tb_hint_unknown_protocol;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(bw_protocol_t'(2'bxx)),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(2)) point
    (.clk(1'b0),.reset_n(1'b1));
  initial begin #1000000;$fatal(1,"expected core error did not occur");end
endmodule
