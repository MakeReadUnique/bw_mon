module tb_hierarchy_depth_transport;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,middle_reset_n=1;
  bit deliver=0,deliver_second=0;
  int point_handles[3],sources[3],missing;
  bw_record_t slow_frame,frame;
  bw_control_t control;
  bw_u64_t raw_sequences[8],raw_ticks[8],raw_edges[8],raw_bytes[8],receipts[8],epochs[8],totals[8];
  bit reset_coverages[8],byte_qualities[8],event_qualities[8];
  bw_mon_setup setup();
  for(genvar g=0;g<8;g++)begin: groups
    bw_group_mon #(.GROUP_ID($sformatf("g%0d",g)),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) mon
      (.clk(clk),.reset_n(g==3 ? middle_reset_n : 1'b1));
    assign raw_sequences[g]=mon.raw_record.record_seq;assign raw_ticks[g]=mon.raw_record.timestamp_ticks;
    assign raw_edges[g]=mon.raw_record.edge_index;assign raw_bytes[g]=mon.raw_record.byte_inc;
    assign receipts[g]=mon.accepted_record_seq;assign epochs[g]=mon.stats_epoch;assign totals[g]=mon.total_bytes;
    assign reset_coverages[g]=mon.member_reset_coverage;assign byte_qualities[g]=mon.bytes_complete;
    assign event_qualities[g]=mon.events_complete;
  end
  always @(deliver)if(deliver)deliver_second<=1;
  always @(deliver_second)if(deliver_second)publish_frame(sources[1],slow_frame);
  task automatic point_control(bw_u64_t record_index,logic reset_value,bw_u64_t epoch);
    control='0;control.point_handle=point_handles[0];control.control_seq=record_index;
    control.timestamp_ticks=$time;control.source_epoch=epoch;control.reset_n=reset_value;
    publish_control(sources[0],control);
  endtask
  initial begin
    if(!$value$plusargs("MISSING=%d",missing))missing=0;
    for(int p=0;p<3;p++)begin
      point_handles[p]=register_point($sformatf("p%0d",p),$sformatf("controlled.p%0d",p),BW_NS,1,1);
      sources[p]=point_source_handle(point_handles[p]);
    end
    add_point_member("g0","p0");add_point_member("g0","p1");
    for(int g=1;g<8;g++)add_group_member($sformatf("g%0d",g),$sformatf("g%0d",g-1));
    add_point_member("g7","p2");wait(monitor_ready);
    for(int p=0;p<3;p++)begin
      control='0;control.point_handle=point_handles[p];control.control_seq=1;control.reset_n=1;
      publish_control(sources[p],control);
    end
    #250000;clk=1;
    frame='0;frame.record_seq=1;frame.edge_index=1;frame.timestamp_ticks=$time;
    frame.byte_inc=64'd4294967295;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    publish_frame(sources[0],frame);publish_frame(sources[2],frame);slow_frame=frame;
    #1;clk=0;
    #(1000003-$time);
    if(groups[7].mon.result_seq!=0 || receipts[7]!=0)
      $fatal(1,"root must retain its logical window while an original leaf frame is pending");
    #(1250002-$time);if(!missing)deliver<=1;
    #1;
    if(missing)$fatal(1,"expected core error did not occur");
    for(int g=0;g<8;g++)begin
      if(raw_sequences[g]!=1 || raw_edges[g]!=1 || raw_ticks[g]!=250000 || receipts[g]!=1 ||
         raw_bytes[g]!=(g==7 ? 64'd12884901885 : 64'd8589934590) || epochs[g]!=0)
        $fatal(1,"eight-level original-deadline NBA completion or wide increment failed atg%0d",g);
    end
    if(groups[7].mon.window_bytes!=64'd12884901885 || groups[7].mon.window_events!=3 ||
       groups[7].mon.window_end_ticks!=1000001 || !groups[7].mon.window_valid ||
       $abs(groups[7].mon.bandwidth_gbps-12884901885.0)>1e-4 || totals[3]!=64'd8589934590 ||
       retained_frame_count(sources[0])!=0 || retained_frame_count(groups[0].mon.transport_source)!=0)
      $fatal(1,"durable subgroup/core reset handling must precede upstream input release");
    #(1500002-$time);middle_reset_n=0;
    #1;
    if(totals[3]!=0 || epochs[3]!=1 || totals[7]!=64'd12884901885 || totals[2]!=64'd8589934590 ||
       raw_sequences[3]!=1 || receipts[3]!=1 || groups[7].mon.control_result_seq!=3 ||
       groups[3].mon.control_result_seq!=2)
      $fatal(1,"middle own reset must clear only its statistics and emit no point-reset control");
    #(1750002-$time);middle_reset_n=1;
    #(2000003-$time);
    if(groups[7].mon.window_bytes!=0 || groups[7].mon.window_events!=0 || !groups[7].mon.window_valid)
      $fatal(1,"stopped hierarchy must expire ns history without inventing missing edges");
    #(2250002-$time);clk=1;
    frame.record_seq=2;frame.edge_index=2;frame.timestamp_ticks=$time;
    for(int p=0;p<3;p++)publish_frame(sources[p],frame);
    #1;clk=0;
    if(totals[7]!=64'd25769803770 || totals[3]!=64'd8589934590 || raw_sequences[7]!=2 || receipts[7]!=2)
      $fatal(1,"middle statistics release cannot rewind source identity or upper history");
    #(2500002-$time);point_control(2,0,1);
    #(3000002-$time);point_control(3,1,1);
    #1;
    for(int g=0;g<8;g++)begin
      if(!reset_coverages[g] || !byte_qualities[g] || !event_qualities[g] || raw_sequences[g]!=2 ||
         epochs[g]!=(g==3 ? 1 : 0))
        $fatal(1,"no-edge actual point reset must propagate coverage without resetting ancestorg%0d",g);
    end
    if(groups[7].mon.raw_control.point_handle!=point_handles[0] || groups[7].mon.raw_control.control_seq!=3 ||
       groups[7].mon.raw_control.timestamp_ticks!=3000001 || groups[7].mon.raw_control.source_epoch!=1 ||
       groups[7].mon.raw_control.reset_n!==1'b1)
      $fatal(1,"every level must preserve originating point/control record_index/epoch/time");
    #(3250002-$time);point_control(4,1'bx,1);
    #(3500002-$time);point_control(5,1,1);
    #(4000003-$time);
    for(int g=0;g<8;g++)if(byte_qualities[g] || event_qualities[g] || raw_sequences[g]!=2)
      $fatal(1,"unknown no-edge reset quality must reach ancestorg%0d without a fake frame",g);
    #(5000003-$time);
    for(int g=0;g<8;g++)if(!byte_qualities[g] || !event_qualities[g] || reset_coverages[g])
      $fatal(1,"ancestor quality should recover exactly after unknown/control history expires atg%0d",g);
    // A sampled observation gap retains every other known contribution through all levels.
    #(5250002-$time);clk=1;
    frame='0;frame.record_seq=3;frame.edge_index=3;frame.timestamp_ticks=$time;
    frame.reset_n=1;frame.source_epoch=1;publish_frame(sources[0],frame);
    frame.source_epoch=0;frame.byte_inc=64'd4294967295;frame.event_inc=1;
    frame.bytes_complete=1;frame.events_complete=1;
    publish_frame(sources[1],frame);publish_frame(sources[2],frame);
    #1;clk=0;
    for(int g=0;g<8;g++)begin
      if(raw_sequences[g]!=3 || raw_edges[g]!=3 || raw_ticks[g]!=5250000 || receipts[g]!=3 ||
         raw_bytes[g]!=(g==7 ? 64'd8589934590 : 64'd4294967295))
        $fatal(1,"sampled observation gap must preserve known raw subtotal at ancestorg%0d",g);
    end
    if(groups[7].mon.raw_record.bytes_complete || groups[7].mon.raw_record.events_complete ||
       groups[7].mon.raw_record.event_inc!=2 || groups[7].mon.raw_record.reset_points!=0 ||
       groups[7].mon.total_bytes!=64'd34359738360)
      $fatal(1,"unknown member cannot erase known events/bytes or impersonate complete zero at the root");
    #(6000003-$time);
    if(groups[7].mon.window_bytes!=64'd8589934590 || groups[7].mon.window_events!=2 ||
       groups[7].mon.bytes_complete || groups[7].mon.events_complete || groups[7].mon.window_valid ||
       groups[7].mon.member_reset_coverage)
      $fatal(1,"partial known raw total and both quality axes must enter the original-time root window");
    // An upper group held in statistics reset still supplies its own ancestors.
    #(6100002-$time);middle_reset_n=0;
    #(6250002-$time);clk=1;
    frame.record_seq=4;frame.edge_index=4;frame.timestamp_ticks=$time;
    for(int p=0;p<3;p++)begin
      frame.source_epoch=(p==0) ? 1 : 0;publish_frame(sources[p],frame);
    end
    #1;clk=0;
    if(epochs[3]!=2 || totals[3]!=0 || receipts[3]!=4 || raw_sequences[3]!=4 ||
       raw_bytes[3]!=64'd8589934590 || receipts[7]!=4 || raw_sequences[7]!=4 ||
       raw_bytes[7]!=64'd12884901885 || totals[7]!=64'd47244640245 || epochs[7]!=0 ||
       groups[7].mon.control_result_seq!=7 || groups[3].mon.control_result_seq!=6 ||
       acknowledged_frame_seq(groups[3].mon.group_handle,0)!=4 ||
       acknowledged_frame_seq(groups[4].mon.group_handle,0)!=4)
      $fatal(1,"held upper-group reset must preserve raw upstream contribution and every consumer position");
    #(7000003-$time);
    if(groups[7].mon.window_bytes!=64'd12884901885 || groups[7].mon.window_events!=3 ||
       !groups[7].mon.window_valid || !groups[7].mon.bytes_complete || !groups[7].mon.events_complete ||
       groups[7].mon.member_reset_coverage || groups[3].mon.window_valid || totals[3]!=0)
      $fatal(1,"ancestor quality/history must recover naturally even while an upper member's local statistics remain reset");
    $display("TB_PASS hierarchy_depth_transport originalT=250000 deadline=1250000 depth=8 root_bytes=12884901885");$finish;
  end
endmodule
