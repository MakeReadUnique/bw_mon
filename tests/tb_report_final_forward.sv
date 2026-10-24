module tb_report_final_forward;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("order.a"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) a
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("order.b"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) b
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  initial begin
    wait(monitor_ready);#1000000;clk=1;#1;clk=0;
    #999999;valid=0;clk=1;#1;clk=0;
    #999999;
    $display("TB_PASS report_final_order");$finish;
  end
endmodule
