module tb_group_basic;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2),.EXPECTED_GROUP_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("p0"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(8)) p0
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("p1"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(16)) p1
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("g"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial begin
    define_group("g",2);
    add_point_member("g","p0");
    add_point_member("g","p1");
    finish_configuration();
    wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    #499999;clk=1;#1;clk=0;
    if(group_mon.raw_record.timestamp_ticks!=750000 || group_mon.raw_record.edge_index!=2 ||
       group_mon.raw_record.record_seq!=2 || group_mon.raw_record.byte_inc!=24 ||
       group_mon.raw_record.event_inc!=2 || !group_mon.raw_record.bytes_complete)
      $fatal(1,"group must sum raw current-edge increments at their original time");
    #499999;clk=1;#1;clk=0;
    #499999;clk=1;#1;clk=0;
    #250000;
    if(group_mon.window_start_ticks!=0 || group_mon.window_end_ticks!=2000000 ||
       group_mon.window_bytes!=96 || group_mon.window_events!=8 ||
       group_mon.total_bytes!=96 || !group_mon.window_full || !group_mon.window_valid ||
       !group_mon.bytes_complete || group_mon.result_seq!=2 ||
       $abs(group_mon.bandwidth_gbps-48.0)>1e-10)
      $fatal(1,"group public window must match independent two-point event table");
    if(p0.window_bytes!=32 || p1.window_bytes!=64 || group_mon.scope_kind!=BW_GROUP ||
       group_mon.accepted_record_seq!=4)
      $fatal(1,"point statistics and group core acceptance must remain independent");
    $display("TB_PASS group_basic");$finish;
  end
endmodule
