// Ticket 56 slice 3: typed pending inventory at an immediate Active finish.
// The interrupting ending names the actual owner stage; no queue drain runs
// and no confirmed-missing warning replaces the interrupt.
module tb_end_pending;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  string mode;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("pending.point"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) p
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("pending.hint"),.WINDOW_BASIS(BW_NS),.WINDOW_WIDTH(200),
    .UPDATE_STRIDE(200),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(10),
    .PROTOCOL(BW_VALID_READY),.BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),
    .BACKPRESSURE_THRESHOLD(200)) h
    (.clk(clk),.reset_n(1'b1),.valid(valid),.ready(1'b0));
  bw_group_mon #(.GROUP_ID("pending.group"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .UPDATE_STRIDE(2),.PHASE_ENABLE(0)) g(.clk(clk),.reset_n(1'b1));
  initial begin
    add_point_member("pending.group","pending.point");
  end
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="edge";
    wait(monitor_ready);
    #1000000;clk=1;#1;clk=0;
    if(mode=="edge") begin
      // Finish in the same Active slot as the second edge: the group still
      // owes the edge commit. Both scopes must name the typed stage, never a
      // fabricated confirmed-missing warning or an end-time queue drain.
      #999999;clk=1;
      $display("TB_PASS end_pending edge ticks=%0d",$time);$finish;
    end
    if(mode=="hint_timer") begin
      // Backpressure started at the first edge; its ns timer was due at
      // 201000001 and its wake delivered. Ending one tick later must settle
      // the interval with the ORIGINAL trigger tick as evidence, never a
      // fabricated or lost threshold confirmation.
      #200000000;
      if($time!=201000002)
        $fatal(1,"hint timer twin must finish one tick past the due tick, got %0d",$time);
      $display("TB_PASS end_pending hint_timer ticks=%0d",$time);$finish;
    end
    $fatal(1,"unknown mode");
  end
endmodule
