module tb_hint_same_cycle_stream;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .CREDIT_RETURN_TIMING(BW_RETURN_SAME_CYCLE),.SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_NS),
    .SHORTAGE_THRESHOLD(2)) ns_point(.clk(clk),.reset_n(1'b1),.flitv(1'b1),.lcrdv(1'b1));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .CREDIT_RETURN_TIMING(BW_RETURN_SAME_CYCLE),.SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_CYCLE),
    .SHORTAGE_THRESHOLD(2)) cycle_point(.clk(clk),.reset_n(1'b1),.flitv(1'b1),.lcrdv(1'b1));
  initial begin
    wait(monitor_ready);
    repeat(5) begin #1000000;clk=1;#1;clk=0;end
    if(!ns_point.credit_trusted || !cycle_point.credit_trusted ||
       ns_point.credit_balance!==64'd0 || cycle_point.credit_balance!==64'd0 ||
       ns_point.credit_send_permitted!==1 || cycle_point.credit_send_permitted!==1 ||
       !ns_point.credit_shortage_known || ns_point.credit_shortage!==0 ||
       !cycle_point.credit_shortage_known || cycle_point.credit_shortage!==0 ||
       ns_point.shortage_active || cycle_point.shortage_active ||
       ns_point.shortage_hit_count!=0 || cycle_point.shortage_hit_count!=0 ||
       ns_point.total_bytes!=40 || cycle_point.total_bytes!=40)
      $fatal(1,"C0/S=R1 same-cycle stream is continuously permitted and must not accrue ns/cycle shortage duration");
    #4999995;
    if(ns_point.shortage_interval_count!=0 || cycle_point.shortage_interval_count!=0 ||
       ns_point.total_bytes!=40 || cycle_point.total_bytes!=40)
      $fatal(1,"held live return availability must not generate shortage or phantom ledger/byte updates while clocks stop");
    $display("TB_PASS hint_same_cycle_stream");$finish;
  end
endmodule
