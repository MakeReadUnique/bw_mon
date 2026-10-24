module tb_hint_final_budget;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(2)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b1),.ready(1'b0));
  initial begin wait(monitor_ready);#(64'd50000000000);$finish;end
endmodule
