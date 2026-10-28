module tb_settle_reset_stream;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset0=1,reset1=1,group_reset=1;
  int mode=0,stage=0,n0=0,n1=0;
  logic levels0[$],levels1[$];
  bw_u64_t epochs0[$];
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("stream.p0"),.PROTOCOL(BW_VALID_READY),.FIXED_BYTES(8),
    .WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5)) p0
    (.clk(clk),.reset_n(reset0),.valid(1'b1),.ready(1'b1));
  bw_point_mon #(.POINT_ID("stream.p1"),.PROTOCOL(BW_CREDIT),.FIXED_BYTES(16),
    .WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(16),.CREDIT_INITIAL(16),.CREDIT_INITIAL_KNOWN(1)) p1
    (.clk(clk),.reset_n(reset1),.flitv(1'b1),.lcrdv(1'b1));
  bw_group_mon #(.GROUP_ID("stream.child"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5)) child(.clk(clk),.reset_n(group_reset));
  bw_group_mon #(.GROUP_ID("stream.parent"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5)) parent(.clk(clk),.reset_n(1'b1));
  settle_reset_stream_driver driver();
  always @(p0.control_toggle)if(monitor_ready && p0.raw_control.control_seq!=0)begin
    n0++;
    if(p0.raw_control.control_seq!=n0 || p0.raw_control.timestamp_ticks!=(n0==1?1:2000001) ||
       p0.raw_control.point_handle!=point_handle_for_id("stream.p0"))
      $fatal(1,"p0 control tuple/receipt must preserve original sequence, time and origin");
    levels0.push_back(p0.raw_control.reset_n);epochs0.push_back(p0.raw_control.source_epoch);
    $display("RESET_STREAM p0 seq=%0d ticks=%0d level=%b epoch=%0d",n0,p0.raw_control.timestamp_ticks,p0.raw_control.reset_n,p0.raw_control.source_epoch);
  end
  always @(p1.control_toggle)if(monitor_ready && p1.raw_control.control_seq!=0)begin
    n1++;
    if(p1.raw_control.control_seq!=n1 || p1.raw_control.timestamp_ticks!=(n1==1?0:2000000) ||
       p1.raw_control.point_handle!=point_handle_for_id("stream.p1"))
      $fatal(1,"p1 control tuple/receipt must preserve original sequence, time and origin");
    levels1.push_back(p1.raw_control.reset_n);
    if(p1.raw_control.source_epoch!=0)$fatal(1,"unknown reset must not assert a known source reset");
  end
  initial begin
    void'($value$plusargs("MODE=%d",mode));
    add_point_member("stream.child","stream.p0");
    add_group_member("stream.parent","stream.child");
    add_point_member("stream.parent","stream.p1");wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    #(2000002-$time);clk=1;stage<=1;
    #1;clk=0;
    if(mode==0)begin
      if(n0!=5 || levels0[0]!==1'b1 || levels0[1]!==1'bz || levels0[2]!==1'bx ||
         levels0[3]!==1'b0 || levels0[4]!==1'b1 || epochs0[0]!=0 || epochs0[1]!=0 ||
         epochs0[2]!=0 || epochs0[3]!=1 || epochs0[4]!=1 ||
         n1!=3 || levels1[0]!==1'b1 || levels1[1]!==1'bx || levels1[2]!==1'b1 ||
         p0.stats_epoch!=1 || p0.total_bytes!=0 || p0.raw_record.byte_inc!=0 ||
         p0.sampled_reset_n!==1'b0 || p0.raw_record.source_epoch!=1 ||
         p1.stats_epoch!=0 || p1.total_bytes!=32 || p1.raw_record.byte_inc!=16 ||
         p1.sampled_reset_n!==1'b1 || !p1.raw_record.bytes_complete ||
         p1.credit_trusted || !p1.credit_anomaly || p1.credit_anomaly_count!=1 ||
         child.control_result_seq!=5 || parent.control_result_seq!=8 || parent.total_bytes!=40 ||
         child.episode_result_seq!=1 || p0.episode_result_seq!=1 ||
         p0.episode_result.status!=BW_EPISODE_RESET_INTERRUPTED || p0.episode_result.byte_count!=8)
        $fatal(1,"ordered four-state controls must survive without a repeated epoch, lost payload or invented beat");
    end else begin
      if(n0!=1 || n1!=1 || p0.stats_epoch!=0 || p0.total_bytes!=16 || p1.total_bytes!=32 ||
         child.control_result_seq!=1 || parent.control_result_seq!=2 || parent.total_bytes!=48 ||
         !p1.credit_trusted || p1.credit_anomaly || parent.episode_bytes_complete!==1'b1)
        $fatal(1,"a group statistics reset must keep point controls, ancestors and credit independent");
    end
    if(child.stats_epoch!=1 || child.total_bytes!=0 || child.result_seq!=1 ||
       child.raw_record.record_seq!=2 || child.raw_record.timestamp_ticks!=2000001 ||
       child.raw_record.byte_inc!=(mode==0?0:8) || parent.raw_record.byte_inc!=(mode==0?16:24) ||
       parent.stats_epoch!=0 || parent.result_seq!=2 || child.accepted_record_seq!=2 || parent.accepted_record_seq!=2 ||
       child.accepted_control_count!=(mode==0?5:1) || parent.accepted_control_count!=(mode==0?8:2) ||
       retained_frame_count(p0.transport_source)!=0 || retained_frame_count(child.transport_source)!=0)
      $fatal(1,"group reset still collects/publishes original-time frames and confirms only after its own receipt");
    #(3000003-$time);
    if(child.window_bytes!=0 || parent.window_bytes!=(mode==0?16:24) ||
       !child.bytes_complete || !parent.bytes_complete || !parent.events_complete ||
       parent.member_reset_coverage!=(mode==0))
      $fatal(1,"zero-duration controls and group-only resets must not fabricate physical unknown/reset coverage");
    $display("TB_PASS settle_reset_stream mode=%0d controls=%0d/%0d",mode,n0,n1);$finish;
  end
endmodule
program settle_reset_stream_driver;
  timeunit 1fs;timeprecision 1fs;
  initial begin
    @(tb_settle_reset_stream.stage);
    tb_settle_reset_stream.group_reset<=0;
    if(tb_settle_reset_stream.mode==0)begin
      tb_settle_reset_stream.reset0<=1'bz;tb_settle_reset_stream.reset1<=1'bx;
    end
    tb_settle_reset_stream.stage<=2;
    @(tb_settle_reset_stream.stage);
    if(tb_settle_reset_stream.mode==0)tb_settle_reset_stream.reset0<=1'bx;
    tb_settle_reset_stream.stage<=3;
    @(tb_settle_reset_stream.stage);
    if(tb_settle_reset_stream.mode==0)tb_settle_reset_stream.reset0<=0;
    tb_settle_reset_stream.stage<=4;
    @(tb_settle_reset_stream.stage);
    tb_settle_reset_stream.reset0<=1;tb_settle_reset_stream.reset1<=1;tb_settle_reset_stream.group_reset<=1;
    wait(1'b0);
  end
endprogram
