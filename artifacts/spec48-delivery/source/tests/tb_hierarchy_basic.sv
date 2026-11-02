module tb_hierarchy_basic;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("child"),.FIXED_BYTES(8),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) point_named_child
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("leaf"),.FIXED_BYTES(16),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) leaf
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("ungrouped"),.FIXED_BYTES(32),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) ungrouped
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("child"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) child
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("parent"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) parent
    (.clk(clk),.reset_n(1'b1));
  initial begin
    add_group_member("parent","child");add_group_member("parent","child");
    add_point_member("parent","child");add_point_member("child","leaf");
    wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    if(child.direct_member_count!=1 || child.recursive_point_count!=1 ||
       parent.direct_member_count!=2 || parent.recursive_point_count!=2 ||
       parent.raw_record.timestamp_ticks!=250001 || parent.raw_record.edge_index!=1 ||
       parent.raw_record.byte_inc!=24 || parent.raw_record.event_inc!=2 ||
       !parent.raw_record.bytes_complete || parent.accepted_record_seq!=1)
      $fatal(1,"typed mixed hierarchy must preserve original edge and raw leaf sum");
    #499999;clk=1;#1;clk=0;
    #250000;
    if(parent.window_bytes!=48 || parent.window_events!=4 || !parent.window_full ||
       parent.window_end_ticks!=1000001 || parent.total_bytes!=48 ||
       child.total_bytes!=32 || point_named_child.total_bytes!=16 || ungrouped.total_bytes!=64 ||
       $abs(parent.bandwidth_gbps-48.0)>1e-10 || retained_frame_count(child.transport_source)!=0)
      $fatal(1,"parent must consume subgroup raw increments once, with independent local statistics");
    $display("TB_PASS hierarchy_basic");$finish;
  end
endmodule
