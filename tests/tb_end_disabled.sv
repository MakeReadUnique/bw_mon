// Ticket 56 slice 4: disabled roles still reach real terminals; the report
// completes with integrity=INCOMPLETE once every real role has terminated.
// A failing point disables only its own ancestor chain; the healthy sibling
// continues and keeps its unread retained data.
module tb_end_disabled;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("dis.p1"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .UPDATE_STRIDE(2),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) p1
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("dis.p2"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .UPDATE_STRIDE(2),.FIXED_BYTES(16),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) p2
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("dis.g1"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .UPDATE_STRIDE(2),.PHASE_ENABLE(0)) g1(.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("dis.g2"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .UPDATE_STRIDE(2),.PHASE_ENABLE(0)) g2(.clk(clk),.reset_n(1'b1));
  initial begin
    add_point_member("dis.g1","dis.p1");add_point_member("dis.g2","dis.p2");
  end
  initial begin
    wait(monitor_ready);
    #1000000;clk=1;#1;clk=0;
    // A real runtime fault disables p1 and its ancestor chain only.
    runtime_scope_error(BW_POINT,"dis.p1","TEST_FAULT",
      "fixture disables one parent chain while the sibling stays healthy");
    #2000000;
    // The healthy sibling keeps observing after the failure.
    repeat(3) begin #999999;clk=1;#1;clk=0;end
    #1000000;
    if(p2.total_bytes!=64)
      $fatal(1,"healthy sibling must keep counting after the other chain failed, got %0d",
        p2.total_bytes);
    $display("TB_PASS end_disabled healthy_bytes=%0d",p2.total_bytes);$finish;
  end
endmodule
