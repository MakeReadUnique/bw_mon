module tb_hierarchy_retention;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,child_reset_n=1;
  int point_handles[12],sources[12],slow;
  string order,mode;
  bw_u64_t first_all_bytes,first_mixed_bytes,first_all_events,first_mixed_events;
  bit point_reset_case,size_case;
  bw_record_t frame;
  bw_control_t control;
  bw_test_consumer_gate gate;
  bit partial_pending=0;
  bw_u64_t partial_seq=0;
  bw_mon_setup setup();
  bw_group_mon #(.GROUP_ID("die0_dmc"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) die0 (.clk(clk),.reset_n(child_reset_n));
  bw_group_mon #(.GROUP_ID("die1_dmc"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) die1 (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("all_dmc"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) all_dmc (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("mixed"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) mixed (.clk(clk),.reset_n(1'b1));
  task automatic publish_point(int point_index,bit first_frame);
    bw_record_t outgoing;
    outgoing=frame;
    if(point_index==0)begin
      outgoing.source_epoch=point_reset_case ? 1 : 0;
      if(first_frame && point_reset_case)begin
        outgoing.byte_inc=0;outgoing.event_inc=0;outgoing.reset_points=1;outgoing.reset_n=0;
      end else if(first_frame && size_case)begin outgoing.byte_inc=0;outgoing.bytes_complete=0;end
    end
    publish_frame(sources[point_index],outgoing);
  endtask
  task automatic check_partial(bw_u64_t record_index,int delayed_point);
    if(retained_frame_count(die0.transport_source)!=1 || die0.accepted_record_seq!=record_index ||
       die0.raw_record.record_seq!=record_index ||
       acknowledged_frame_seq(die0.group_handle,0)!=record_index || retained_frame_count(sources[0])!=0 ||
       retained_frame_count(sources[1])!=0 || retained_frame_count(sources[2])!=0 || retained_frame_count(sources[3])!=0)
      $fatal(1,"completed leaves must release while their one shared group record waits for the second direct parent");
    if(delayed_point==9)begin
      if(all_dmc.accepted_record_seq!=record_index || mixed.accepted_record_seq!=record_index-1 ||
         acknowledged_frame_seq(all_dmc.group_handle,0)!=record_index ||
         acknowledged_frame_seq(mixed.group_handle,0)!=record_index-1 ||
         retained_frame_count(die1.transport_source)!=0 || retained_frame_count(sources[8])!=1)
        $fatal(1,"all_dmc-first order must retain die0 only for mixed, and mixed's unread direct point");
    end else begin
      if(mixed.accepted_record_seq!=record_index || all_dmc.accepted_record_seq!=record_index-1 ||
         acknowledged_frame_seq(mixed.group_handle,0)!=record_index ||
         acknowledged_frame_seq(all_dmc.group_handle,0)!=record_index-1 || retained_frame_count(sources[4])!=1 ||
         retained_frame_count(sources[8])!=0 || retained_frame_count(sources[9])!=0)
        $fatal(1,"mixed-first order must retain die0 only for all_dmc, and the incomplete die1 leaf frame");
    end
  endtask
  initial begin
    if(!$value$plusargs("ORDER=%s",order))order="all_first";
    if(!$value$plusargs("MODE=%s",mode))mode="normal";
    point_reset_case=(mode=="point_reset");size_case=(mode=="size_unknown");
    first_all_bytes=(point_reset_case || size_case) ? 448 : 512;
    first_mixed_bytes=(point_reset_case || size_case) ? 320 : 384;
    first_all_events=point_reset_case ? 7 : 8;first_mixed_events=point_reset_case ? 5 : 6;
    for(int p=0;p<12;p++)begin
      point_handles[p]=register_point($sformatf("p%0d",p),$sformatf("controlled.p%0d",p),BW_NS,1,1);
      sources[p]=point_source_handle(point_handles[p]);
    end
    for(int p=0;p<4;p++)add_point_member("die0_dmc",$sformatf("p%0d",p));
    for(int p=4;p<8;p++)add_point_member("die1_dmc",$sformatf("p%0d",p));
    add_group_member("all_dmc","die0_dmc");add_group_member("all_dmc","die1_dmc");
    add_group_member("mixed","die0_dmc");add_point_member("mixed","p8");add_point_member("mixed","p9");
    wait(monitor_ready);
    for(int p=0;p<12;p++)begin
      control='0;control.point_handle=point_handles[p];control.control_seq=1;control.reset_n=1;control.timestamp_ticks=measurement_start_ticks;
      publish_control(sources[p],control);
    end
    #103900000;
    if(mode=="child_reset")child_reset_n=0;
    if(point_reset_case)begin
      control='0;control.point_handle=point_handles[0];control.control_seq=2;control.source_epoch=1;
      control.timestamp_ticks=$time;control.reset_n=0;publish_control(sources[0],control);
    end
    #(measurement_start_ticks+104000000-$time);clk=1;slow=(order=="all_first") ? 9 : 7;
    frame='0;frame.record_seq=1;frame.edge_index=1;frame.timestamp_ticks=$time;
    frame.byte_inc=64;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    gate=bw_test_gate_for(slow==9 ? "mixed" : "die1_dmc");
    gate.resume_after_group=slow==9 ? "all_dmc" : "mixed";gate.resume_after_seq=1;gate.paused=1;
    partial_seq=1;partial_pending=1;
    for(int p=0;p<12;p++)publish_point(p,1);
    #1;clk=0;
    if(retained_frame_count(sources[10])!=0 || retained_frame_count(sources[11])!=0)
      $fatal(1,"ungrouped sources must not retain ancestor transport copies");
    if(partial_pending)$fatal(1,"same-time partial receipt observation missing");
    if(all_dmc.raw_record.timestamp_ticks!=measurement_start_ticks+104000000 || mixed.raw_record.timestamp_ticks!=measurement_start_ticks+104000000 ||
       all_dmc.raw_record.edge_index!=1 || mixed.raw_record.edge_index!=1 ||
       all_dmc.raw_record.byte_inc!=first_all_bytes || mixed.raw_record.byte_inc!=first_mixed_bytes ||
       all_dmc.raw_record.event_inc!=first_all_events || mixed.raw_record.event_inc!=first_mixed_events ||
       all_dmc.raw_record.bytes_complete==size_case || mixed.raw_record.bytes_complete==size_case ||
       !all_dmc.raw_record.events_complete || !mixed.raw_record.events_complete ||
       all_dmc.raw_record.reset_points!=bw_u64_t'(point_reset_case) ||
       mixed.raw_record.reset_points!=bw_u64_t'(point_reset_case) ||
       all_dmc.total_bytes!=first_all_bytes || mixed.total_bytes!=first_mixed_bytes ||
       die0.stats_epoch!=bw_u64_t'(mode=="child_reset") || all_dmc.stats_epoch!=0 || mixed.stats_epoch!=0 ||
       retained_frame_count(die0.transport_source)!=0)
      $fatal(1,"same-time slow direct consumer must receive the same original group frame without an extra statistics cycle");
    #(measurement_start_ticks+104450000-$time);child_reset_n=1;
    if(point_reset_case)begin
      control.control_seq=3;control.timestamp_ticks=$time;control.reset_n=1;
      publish_control(sources[0],control);
    end
    // Reverse the parent order on the next actual edge; no consumer cursor resets.
    #(measurement_start_ticks+104500000-$time);clk=1;slow=(slow==9) ? 7 : 9;
    frame.record_seq=2;frame.edge_index=2;frame.timestamp_ticks=$time;
    gate=bw_test_gate_for(slow==9 ? "mixed" : "die1_dmc");
    gate.resume_after_group=slow==9 ? "all_dmc" : "mixed";gate.resume_after_seq=2;gate.paused=1;
    partial_seq=2;partial_pending=1;
    for(int p=0;p<12;p++)publish_point(p,0);
    #1;clk=0;
    if(partial_pending)$fatal(1,"reverse same-time partial observation missing");
    if(all_dmc.accepted_record_seq!=2 || mixed.accepted_record_seq!=2 ||
       all_dmc.total_bytes!=first_all_bytes+512 || all_dmc.total_events!=first_all_events+8 ||
       mixed.total_bytes!=first_mixed_bytes+384 || mixed.total_events!=first_mixed_events+6 ||
       retained_frame_count(die0.transport_source)!=0 || retained_frame_count(die1.transport_source)!=0)
      $fatal(1,"opposite lawful consumer orders must preserve sums and release only fully acknowledged source data");
    #(measurement_start_ticks+105000001-$time);
    if(all_dmc.window_start_ticks!=measurement_start_ticks+104000000 || all_dmc.window_end_ticks!=measurement_start_ticks+105000000 ||
       all_dmc.window_bytes!=first_all_bytes+512 || all_dmc.window_events!=first_all_events+8 ||
       all_dmc.window_valid==size_case || all_dmc.bytes_complete==size_case || !all_dmc.events_complete ||
       all_dmc.member_reset_coverage!=point_reset_case ||
       mixed.window_bytes!=first_mixed_bytes+384 || mixed.window_events!=first_mixed_events+6 ||
       mixed.window_valid==size_case || mixed.bytes_complete==size_case || !mixed.events_complete ||
       mixed.member_reset_coverage!=point_reset_case)
      $fatal(1,"same-time consumer progress must preserve exact original-time half-open windows");
    $display("TB_PASS hierarchy_retention order=%s mode=%s T104=%0d/%0d,%0d/%0d leaf_streams_released_before_second_parent",
      order,mode,first_all_bytes,first_all_events,first_mixed_bytes,first_mixed_events);$finish;
  end
  task automatic observe_partial();
    forever begin
      wait(partial_pending);
      if(slow==9)wait(group_batches["all_dmc"].acked==partial_seq);
      else wait(group_batches["mixed"].acked==partial_seq);
      check_partial(partial_seq,slow);partial_pending=0;
    end
  endtask
  hierarchy_retention_observer observer();
endmodule
program hierarchy_retention_observer;
  initial tb_hierarchy_retention.observe_partial();
endprogram
