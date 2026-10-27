module tb_settle_group_reset;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  int mode=0,bad_upstream_frames=0,public_assertions=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2),.EXPECTED_GROUP_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("settle.p0"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(8)) p0
    (.clk(clk),.reset_n(reset_n),.valid(1'b1));
  bw_point_mon #(.POINT_ID("settle.p1"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(16)) p1
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("settle.child"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) child
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("settle.parent"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) parent
    (.clk(clk),.reset_n(1'b1));
  settle_group_reset_driver driver();
  always @(posedge(p0.reset_n===1'b0))public_assertions++;
  always @(child.record_toggle)
    if($time==2000000 && child.raw_record.byte_inc!=(mode==4?8:0))bad_upstream_frames++;
  initial begin
    void'($value$plusargs("MODE=%d",mode));if(mode==3)reset_n=0;
    define_group("settle.child",1);add_point_member("settle.child","settle.p0");
    define_group("settle.parent",2);add_group_member("settle.parent","settle.child");
    add_point_member("settle.parent","settle.p1");finish_configuration();wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    #(2000000-$time);clk=1;if(mode==0)reset_n<=0;
    #1;clk=0;
    $display("SETTLE_GROUP_VALUES mode=%0d ticks=%0d live_reset=%b sampled_reset=%b raw=%0d child_raw=%0d parent_raw=%0d own_total=%0d child_total=%0d parent_total=%0d own_epoch=%0d own_window_seq=%0d bad_upstream_frames=%0d receipts=%0d/%0d/%0d public_assertions=%0d",
      mode,$time,reset_n,p0.sampled_reset_n,p0.raw_record.byte_inc,child.raw_record.byte_inc,parent.raw_record.byte_inc,
      p0.total_bytes,child.total_bytes,parent.total_bytes,p0.stats_epoch,p0.result_seq,bad_upstream_frames,
      p0.accepted_record_seq,child.accepted_record_seq,parent.accepted_record_seq,public_assertions);
    if(p0.accepted_record_seq!=2 || child.accepted_record_seq!=2 || parent.accepted_record_seq!=2 ||
       bad_upstream_frames!=0 || p0.raw_record.record_seq!=2 || p0.raw_record.timestamp_ticks!=2000000 ||
       p0.raw_record.byte_inc!=(mode==4?8:0) || p0.raw_record.event_inc!=(mode==4?1:0) ||
       p0.sampled_reset_n!==(mode==4?1'b1:1'b0) ||
       p0.raw_record.source_epoch!=(mode==4?0:1) ||
       child.raw_record.byte_inc!=(mode==4?8:0) || parent.raw_record.byte_inc!=(mode==4?24:16) ||
       child.raw_record.record_seq!=2 || parent.raw_record.record_seq!=2 ||
       child.raw_record.timestamp_ticks!=2000000 || parent.raw_record.timestamp_ticks!=2000000 ||
       child.stats_epoch!=0 || parent.stats_epoch!=0 || child.result_seq!=2 || parent.result_seq!=2 ||
       child.window_bytes!=(mode==3?0:8) || parent.window_bytes!=(mode==3?16:24) ||
       child.total_bytes!=(mode==3?0:mode==4?16:8) || parent.total_bytes!=(mode==3?32:mode==4?48:40) ||
       child.accepted_control_count!=(mode==2?3:2) || parent.accepted_control_count!=(mode==2?4:3) ||
       retained_frame_count(p0.transport_source)!=0 || retained_frame_count(child.transport_source)!=0)
      $fatal(1,"same-T reset/control ordering must preserve raw ancestor traffic, history, identities and receipt-before-ACK");
    if(mode!=4 && (p0.stats_epoch!=1 || p0.total_bytes!=0))
      $fatal(1,"known reset must clear only the own point statistics");
    #(3000001-$time);
    if(child.window_bytes!=(mode==4?8:0) || parent.window_bytes!=(mode==4?24:16) ||
       child.bytes_complete!=(mode!=4) || parent.bytes_complete!=(mode!=4) ||
       child.events_complete!=(mode!=4) || parent.events_complete!=(mode!=4) ||
       child.member_reset_coverage!=(mode!=4) || parent.member_reset_coverage!=(mode!=4))
      $fatal(1,"positive unknown/reset coverage and known-part counts must remain independent upstream");
    $display("TB_PASS settle_group_reset mode=%0d",mode);$finish;
  end
endmodule
program settle_group_reset_driver;
  timeunit 1fs;timeprecision 1fs;
  initial begin
    wait(bw_mon_pkg::monitor_ready);#2000000;
    case(tb_settle_group_reset.mode)
      1,2:tb_settle_group_reset.reset_n<=0;
      3:tb_settle_group_reset.reset_n<=1;
      4:tb_settle_group_reset.reset_n<=1'bx;
    endcase
    if(tb_settle_group_reset.mode==2)begin
      @(negedge tb_settle_group_reset.reset_n);tb_settle_group_reset.reset_n<=1;
    end
  end
endprogram
