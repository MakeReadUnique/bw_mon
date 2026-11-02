module tb_auto_reset_slot;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic reset_n=1,clk=0;
  int step=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("slot.p0"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.FIXED_BYTES(8),.PHASE_ENABLE(0)) p0
    (.clk(clk),.reset_n(reset_n),.valid(1'b1));
  bw_point_mon #(.POINT_ID("slot.p1"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.FIXED_BYTES(16),.PHASE_ENABLE(0)) p1
    (.clk(clk),.reset_n(1'b0),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("slot.child"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) child
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("slot.parent"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) parent_group
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("slot.peer"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) peer
    (.clk(clk),.reset_n(1'b1));
  initial begin
    add_point_member("slot.child","slot.p0");add_point_member("slot.child","slot.p1");
    add_group_member("slot.parent","slot.child");add_group_member("slot.peer","slot.child");
    #1;step<=1;
  end
  always @(step) if(step>0 && step<=20) begin
    reset_n<=!reset_n;
    if(step<20)step<=step+1;
  end
  initial begin
    wait(monitor_ready);
    // Independent input oracle: initial level +20 transitions on p0, one
    // initial held-reset level on p1, hence22 controls through every group.
    if(step!=20 || $time!=measurement_start_ticks || measurement_start_ticks!=1 ||
       p0.raw_control.control_seq!=21 || p1.raw_control.control_seq!=1 ||
       p0.stats_epoch!=10 || p1.stats_epoch!=1 ||
       child.accepted_control_count!=22 || child.control_result_seq!=22 ||
       parent_group.accepted_control_count!=22 || parent_group.control_result_seq!=22 ||
       peer.accepted_control_count!=22 || peer.control_result_seq!=22 ||
       retained_control_count(p0.transport_source)!=0 || retained_control_count(p1.transport_source)!=0 ||
       retained_control_count(child.transport_source)!=0)
      $fatal(1,"ready must include all initial-slot controls, core receipts, publications and direct ACKs");
    if(p0.total_events!=0 || p1.total_events!=0 || child.total_events!=0)
      $fatal(1,"startup reset transitions must not manufacture transfer events");
    #1;clk=1;#1;clk=0;
    if(p0.total_bytes!=8 || p1.total_bytes!=0 || child.total_bytes!=8 ||
       parent_group.total_bytes!=8 || peer.total_bytes!=8 || child.accepted_record_seq!=1)
      $fatal(1,"first post-T edge must use the completed startup reset state");
    $display("TB_PASS auto_reset_slot controls=22 scopes=5");$finish;
  end
  initial begin #3;if(!monitor_ready)$fatal(1,"startup stalled beyond its seal slot");end
endmodule
