module tb_group_reset_quality;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,point_reset_n=1,group_reset_n=1,valid=1;
  logic [63:0] size_bytes=8;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("p0"),.DYNAMIC_BYTES(1),.WINDOW_WIDTH(4),.UPDATE_STRIDE(1)) p0
    (.clk(clk),.reset_n(point_reset_n),.valid(valid),.size_bytes(size_bytes),.size_known(1'b1));
  bw_point_mon #(.POINT_ID("p1"),.FIXED_BYTES(16),.WINDOW_WIDTH(4),.UPDATE_STRIDE(1)) p1
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("reset.group"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(group_reset_n));
  task automatic sample(bw_u64_t ticks,logic valid_now,logic [63:0] bytes_now);
    #(ticks-$time-1);valid=valid_now;size_bytes=bytes_now;
    #1;clk=1;#1;clk=0;
  endtask
  initial begin
    add_point_member("reset.group","p0");add_point_member("reset.group","p1");
    wait(monitor_ready);
    sample(250000,1,8);sample(750000,1,0);sample(1250000,1,'x);sample(1750000,1'bx,8);
    #(2000003-$time);
    if(group_mon.window_bytes!=72 || group_mon.window_events!=7 || group_mon.bytes_complete ||
       group_mon.events_complete || group_mon.stats_epoch!=0 || group_mon.member_reset_coverage)
      $fatal(1,"known group subtotal/quality must follow independent mixed-event table");
    #(2250002-$time);point_reset_n=0;
    #750001;
    if(group_mon.total_bytes!=72 || group_mon.stats_epoch!=0 || !group_mon.member_reset_coverage ||
       group_mon.raw_record.record_seq!=4 || p0.stats_epoch!=1)
      $fatal(1,"no-edge point reset must preserve group history and propagate physical coverage");
    #249999;group_reset_n=0;
    sample(3375000,1,8);
    if(group_mon.stats_epoch!=1 || group_mon.total_bytes!=0 || group_mon.accepted_record_seq!=5 ||
       group_mon.raw_record.byte_inc!=16 || group_mon.raw_record.event_inc!=1 ||
       group_mon.raw_record.reset_points!=1 || !group_mon.raw_record.bytes_complete)
      $fatal(1,"group statistics reset must still collect/publish/ack raw known member increments");
    #(3500002-$time);group_reset_n=1;
    #250000;point_reset_n=1;valid=1;size_bytes=8;
    sample(4000000,1,8);sample(4500000,1,8);
    if(group_mon.total_bytes!=48 || group_mon.window_bytes!=24 || group_mon.window_events!=2 ||
       group_mon.window_start_ticks!=3500001 || group_mon.window_end_ticks!=4500001 ||
       !group_mon.bytes_complete || !group_mon.events_complete || !group_mon.member_reset_coverage ||
       group_mon.raw_record.record_seq!=7 || group_mon.raw_record.source_epoch!=0 ||
       p0.raw_record.source_epoch!=1 || p0.raw_record.record_seq!=7 || p1.total_bytes!=112 ||
       $abs(group_mon.bandwidth_gbps-24.0)>1e-10)
      $fatal(1,"local reset independence, continued source order or coverage restoration is wrong");
    #(5000002-$time);group_reset_n=0;
    sample(5250000,1,8);
    if(group_mon.total_bytes!=0 || group_mon.stats_epoch!=2 || group_mon.raw_record.byte_inc!=24 ||
       group_mon.raw_record.reset_points!=0 || group_mon.control_result_seq!=4 ||
       group_mon.accepted_record_seq!=8 || p0.stats_epoch!=1 || p1.stats_epoch!=0)
      $fatal(1,"group-only reset must never create an actual point reset or reset another scope");
    #(5500002-$time);group_reset_n=1;
    sample(6000000,1,8);sample(6500000,1,8);
    if(group_mon.total_bytes!=48 || group_mon.window_bytes!=24 || group_mon.member_reset_coverage ||
       !group_mon.bytes_complete || group_mon.window_start_ticks!=5500001 ||
       group_mon.window_end_ticks!=6500001 || group_mon.raw_record.record_seq!=10 ||
       group_mon.accepted_record_seq!=10 || p0.total_bytes!=40 || p1.total_bytes!=160 ||
       acknowledged_frame_seq(group_mon.group_handle,0)!=10 ||
       acknowledged_frame_seq(group_mon.group_handle,1)!=10)
      $fatal(1,"fresh group statistics must not rewind transport or rescale member traffic");
    $display("TB_PASS group_reset_quality");$finish;
  end
endmodule
