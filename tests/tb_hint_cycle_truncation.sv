module tb_hint_cycle_truncation;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_u64_t held_seq;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_CYCLE),.BACKPRESSURE_THRESHOLD(3)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.ready(1'b0));
  initial begin
    wait(monitor_ready);
    #1000000;clk=1;#1;clk=0;#999999;clk=1;#1;clk=0;
    held_seq=point.backpressure_result_seq;
    #7999999;
    if(!point.backpressure_active || point.backpressure_hit || point.backpressure_duration_cycles!=1 ||
       point.backpressure_result_seq!=held_seq)
      $fatal(1,"observation truncation cannot invent cycles or trigger from physical stopped-clock time");
    $display("TB_PASS hint_cycle_truncation");$finish;
  end
endmodule
