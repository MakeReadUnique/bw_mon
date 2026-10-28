module tb_auto_start_chain;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  int step=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("chain.p0"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(2),.FIXED_BYTES(8),.PHASE_ENABLE(0)) p0
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("chain.p1"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(2),.FIXED_BYTES(16),.PHASE_ENABLE(0)) p1
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("chain.p2"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(2),.FIXED_BYTES(32),.PHASE_ENABLE(0)) p2
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_group_mon #(.GROUP_ID("chain.child"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(2),.PHASE_ENABLE(0)) child
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("chain.root"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(2),.PHASE_ENABLE(0)) root_group
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("chain.peer"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(2),.PHASE_ENABLE(0)) peer
    (.clk(clk),.reset_n(1'b1));
  initial begin
    // Rules can reference owners/members before their own initial registration.
    add_group_member("chain.root","chain.child");
    repeat(32) #0;
    step<=1;
  end
  always @(step) if(step>0) begin
    case(step)
      1: add_point_member("chain.child","chain.p0");
      40: add_point_member("chain.child","chain.p1");
      79: add_point_member("chain.child","chain.p0"); // duplicate hit
      80: begin
        add_group_member("chain.peer","chain.child");
        add_point_member("chain.root","chain.p2");
      end
    endcase
    if(step<80)step<=step+1;
  end
  initial begin
    bw_report_summary_t summary;
    wait(monitor_ready);
    if(step!=80 || $time!=measurement_start_ticks || measurement_start_ticks==0)
      $fatal(1,"finite #0/NBA collection must finish before one positive-slot start");
    if(child.direct_member_count!=2 || root_group.direct_member_count!=2 ||
       root_group.recursive_point_count!=3 || peer.direct_member_count!=1 || peer.recursive_point_count!=2)
      $fatal(1,"typed deduplication, mixed hierarchy and multiple parents must retain exact membership");
    summary=check_report_summary();
    if(summary.scopes_expected!=6) $fatal(1,"all intermediate groups must enter reporting");
    #1000000; valid=1;clk=1;#1;clk=0;valid=0;
    #999999;clk=1;#1;clk=0;
    if(p0.total_bytes!=8 || p1.total_bytes!=16 || p2.total_bytes!=32 ||
       child.total_bytes!=24 || root_group.total_bytes!=56 || peer.total_bytes!=24 ||
       root_group.window_end_ticks!=measurement_start_ticks+2000000 || root_group.window_bytes!=56)
      $fatal(1,"raw leaf sums and T-relative first publication must agree");
    $display("TB_PASS auto_start_chain");$finish;
  end
endmodule
