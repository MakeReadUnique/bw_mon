module tb_group_matching;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(3),.EXPECTED_GROUP_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("tb.noc1.p0"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(8)) p0
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("tb.noc1.p1"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(16)) p1
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("tb.noc10.p2"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(64)) ungrouped
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("noc1"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) both
    (.clk(clk),.reset_n(1'b1));
  // Equal point/group names are legal separate typed namespaces.
  bw_group_mon #(.GROUP_ID("tb.noc1.p0"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) reuse
    (.clk(clk),.reset_n(1'b1));
  initial begin
    define_group("noc1",2);
    add_point_member("noc1","tb.noc1",BW_PREFIX);
    add_point_member("noc1","tb.noc1.p0");
    define_group("tb.noc1.p0",1);
    add_point_member("tb.noc1.p0","tb.noc1.p0");
    finish_configuration();wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    #499999;clk=1;#1;clk=0;
    #499999;clk=1;#1;clk=0;
    #499999;clk=1;#1;clk=0;
    #250000;
    if (both.direct_member_count!=2 || both.recursive_point_count!=2 || reuse.direct_member_count!=1 ||
        both.window_bytes!=96 || both.window_events!=8 || reuse.window_bytes!=32 ||
        reuse.window_events!=4 || ungrouped.window_bytes!=256 || ungrouped.total_events!=4 ||
        $abs(both.bandwidth_gbps-48.0)>1e-10 || $abs(reuse.bandwidth_gbps-16.0)>1e-10 ||
        $abs(ungrouped.bandwidth_gbps-128.0)>1e-10)
      $fatal(1,"prefix segment boundary, deduplication, reuse or ungrouped counting is wrong");
    if (retained_frame_count(point_source_handle(p0.source_handle))!=0 ||
        retained_control_count(point_source_handle(p0.source_handle))!=0)
      $fatal(1,"all automatic direct consumers must acknowledge before storage is released");
    $display("TB_PASS group_matching");$finish;
  end
endmodule
