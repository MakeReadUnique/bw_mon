// Controlled original-edge producers plus real public group consumers. The
// aggregate4096 peak does not claim a4096-entry individual source buffer.
module tb_transport_same_time_pressure;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  int points[4096],sources[4096];
  bit checked=0,cancel_slow=0;
  bw_record_t frame;
  bw_control_t control;
  bw_test_consumer_gate gate;
  bw_mon_setup setup();
  bw_group_mon #(.GROUP_ID("pressure.fast"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) fast(.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("pressure.slow"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) slow(.clk(clk),.reset_n(1'b1));
  initial begin
    cancel_slow=$test$plusargs("CANCEL_SLOW");
    for(int p=0;p<4096;p++)begin
      points[p]=register_point($sformatf("p%0d",p),$sformatf("controlled.p%0d",p),BW_CYCLE,2,2);sources[p]=point_source_handle(points[p]);
      add_point_member("pressure.fast",$sformatf("p%0d",p));add_point_member("pressure.slow",$sformatf("p%0d",p));
    end
    wait(monitor_ready);
    // The controlled producer seam does not require public reset preparation.
    // p0 supplies the control stream under test; other producers supply frames.
    control='0;control.point_handle=points[0];control.control_seq=1;control.reset_n=1;control.timestamp_ticks=$time;publish_control(sources[0],control);
    #1000000;
    gate=bw_test_gate_for("pressure.slow");gate.resume_after_group="pressure.fast";gate.resume_after_seq=1;gate.paused=1;
    clk=1;
    control='0;control.point_handle=points[0];control.control_seq=2;control.timestamp_ticks=$time;control.reset_n=0;control.source_epoch=1;publish_control(sources[0],control);
    control.control_seq=3;control.reset_n=1;publish_control(sources[0],control);
    for(int p=0;p<4096;p++)begin
      frame='0;frame.timestamp_ticks=$time;frame.record_seq=1;frame.edge_index=1;frame.source_epoch=(p==0)?1:0;
      frame.byte_inc=1;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;publish_frame(sources[p],frame);
    end
    #1;
    if(!checked || fast.accepted_record_seq!=1 || slow.accepted_record_seq!=(cancel_slow?0:1) || fast.total_bytes!=4096 || slow.total_bytes!=(cancel_slow?0:4096))
      $fatal(1,"aggregate pressure did not complete public group/core receipts at original edge");
    for(int p=0;p<4096;p++)if(retained_frame_count(sources[p])!=0 || retained_control_count(sources[p])!=0)
      $fatal(1,"aggregate source%0d leaked after all effective ACKs",p);
    $display("TB_PASS transport_same_time_pressure scope=controlled_sources_public_groups original_ticks=1000001 aggregate_frames=4096 controls=2 per_source_frames=1 release=0");$finish;
  end
  task automatic observe();
    int frames,controls;
    wait(group_batches.exists("pressure.fast"));
    wait(group_batches["pressure.fast"].acked==1);
    frames=0;controls=0;
    for(int p=0;p<4096;p++)begin
      frames+=retained_frame_count(sources[p]);controls+=retained_control_count(sources[p]);
      if(acknowledged_frame_seq(fast.group_handle,p)!=1 || acknowledged_frame_seq(slow.group_handle,p)!=0)
        $fatal(1,"aggregate independent cursor differs source%0d",p);
    end
    if($time!=1000001 || frames!=4096 || controls!=2 || !gate.paused)$fatal(1,"aggregate same-time actual retention differs frames=%0d controls=%0d",frames,controls);
    if(cancel_slow)begin
      runtime_scope_error(BW_GROUP,"pressure.slow","TEST_CONSUMER_FAILURE","same-time consumer cancellation with4096 unread frames");
      acknowledge_member_frame(slow.group_handle,0,1);
      if(acknowledged_frame_seq(slow.group_handle,0)!=0 || scope_disabled(BW_GROUP,"pressure.fast"))$fatal(1,"cancelled ACK changed cursor or disabled sibling");
      for(int p=0;p<4096;p++)if(scope_disabled(BW_POINT,$sformatf("p%0d",p)))$fatal(1,"consumer failure disabled source%0d",p);
    end
    checked=1;$display("TB_PRESSURE_PEAK original_ticks=%0d frames=%0d controls=%0d",$time,frames,controls);
  endtask
  pressure_observer observer();
endmodule
program pressure_observer;
  initial tb_transport_same_time_pressure.observe();
endprogram
