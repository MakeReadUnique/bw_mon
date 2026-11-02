module tb_auto_end_before_ready;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("early.point"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),
    .FIXED_BYTES(8),.PHASE_ENABLE(0)) point_mon
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  initial begin
    #0;
    $finish;
  end
endmodule
