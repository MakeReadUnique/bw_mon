// Ticket 56 slice 1: registration, one global audit before any settlement,
// and one unique report-complete marker after all owner finals.
module tb_end_audit;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  string mode;
  bw_mon_setup setup();
`ifdef REVERSE_DECL
  bw_group_mon #(.GROUP_ID("end.group"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.PHASE_ENABLE(0)) g
    (.clk(clk),.reset_n(1'b1));
  bw_point_mon #(.POINT_ID("end.b"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) b
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("end.a"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2),
    .PROTOCOL(BW_VALID_READY),.BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_CYCLE),
    .BACKPRESSURE_THRESHOLD(10)) a
    (.clk(clk),.reset_n(1'b1),.valid(valid),.ready(1'b1));
`else
  bw_point_mon #(.POINT_ID("end.a"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2),
    .PROTOCOL(BW_VALID_READY),.BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_CYCLE),
    .BACKPRESSURE_THRESHOLD(10)) a
    (.clk(clk),.reset_n(1'b1),.valid(valid),.ready(1'b1));
  bw_point_mon #(.POINT_ID("end.b"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) b
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_group_mon #(.GROUP_ID("end.group"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.PHASE_ENABLE(0)) g
    (.clk(clk),.reset_n(1'b1));
`endif
  initial begin
    add_point_member("end.group","end.a");add_point_member("end.group","end.b");
  end
`ifdef BW_MON_TEST_END_FAULTS
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="normal";
    if(mode=="suppress_hint")suppress_end_receipt(scope_key(BW_POINT,"end.a"),"hint");
    if(mode=="suppress_core")suppress_end_receipt(scope_key(BW_POINT,"end.a"),"core");
    if(mode=="suppress_owner")suppress_end_receipt(scope_key(BW_POINT,"end.a"),"owner");
  end
`endif
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="normal";
    wait(monitor_ready);
    // Five active edges with valid traffic, then silence closes every episode.
    #1000000;clk=1;#1;clk=0;
    repeat(4) begin #999999;clk=1;#1;clk=0;end
    valid=0;
    repeat(2) begin #999999;clk=1;#1;clk=0;end
    #1000000;
    $display("TB_PASS end_audit mode=%s",$sformatf("%s",mode));$finish;
  end
endmodule
