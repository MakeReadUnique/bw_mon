module tb_transport_growth;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  int slow_point,slow_source,fast_source;
  bw_record_t frame;
  bw_control_t control;
  int prompt_checks=0,delayed_checks=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("growth.fast"),.FIXED_BYTES(8),.WINDOW_WIDTH(100),.UPDATE_STRIDE(100)) fast
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("growth.delayed"),.WINDOW_WIDTH(100),.UPDATE_STRIDE(100)) delayed
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("growth.prompt"),.WINDOW_WIDTH(100),.UPDATE_STRIDE(100)) prompt
    (.clk(clk),.reset_n(1'b1));
  transport_growth_checker observer();
  initial begin
    add_point_member("growth.delayed","growth.fast");add_point_member("growth.delayed","growth.slow");
    add_point_member("growth.prompt","growth.fast");
    slow_point=register_point("growth.slow","controlled.source",BW_NS,100,100);
    slow_source=point_source_handle(slow_point);wait(monitor_ready);
    fast_source=point_source_handle(point_handle_for_id("growth.fast"));
    control='0;control.point_handle=slow_point;control.control_seq=1;control.reset_n=1;
    publish_control(slow_source,control);set_source_progress(slow_source,250000);
    #250000;
    repeat(4096)begin clk=1;#1;clk=0;#499999;end
    if(fast.raw_record.record_seq!=4096 || prompt.accepted_record_seq!=4096 ||
       delayed.accepted_record_seq!=0 || delayed.result_seq!=0 || prompt_checks!=20 ||
       retained_frame_count(fast_source)!=4096 || retained_control_count(slow_source)!=2 ||
       acknowledged_frame_seq(prompt.group_handle,0)!=4096 || acknowledged_frame_seq(delayed.group_handle,0)!=0)
      $fatal(1,"a prompt direct consumer must progress while4096 original frames and earlier controls remain durable for the other");
    for(int i=0;i<4096;i++)begin
      frame='0;frame.record_seq=bw_u64_t'(i)+1;frame.edge_index=frame.record_seq;
      frame.timestamp_ticks=250000+bw_u64_t'(i)*500000;frame.reset_n=1;
      frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;
      if(frame.timestamp_ticks>=500000001 && frame.timestamp_ticks<501000000)begin
        frame.reset_n=1'bx;frame.byte_inc=0;frame.event_inc=0;frame.bytes_complete=0;frame.events_complete=0;
      end
      publish_frame(slow_source,frame);
    end
    set_source_progress(slow_source,BW_U64_MAX);
    wait(delayed.accepted_record_seq==4096);#1;
    if(delayed.raw_record.timestamp_ticks!=2047750001 || delayed.raw_record.edge_index!=4096 ||
       delayed.total_bytes!=65520 || delayed.total_events!=8190 || delayed_checks!=20 ||
       delayed.window_start_ticks!=1900000000 || delayed.window_end_ticks!=2000000000 ||
       delayed.window_bytes!=3200 || delayed.window_events!=400 || !delayed.window_valid ||
       !delayed.bytes_complete || !delayed.events_complete || delayed.member_reset_coverage ||
       retained_frame_count(fast_source)!=0 || retained_frame_count(slow_source)!=0 || retained_control_count(slow_source)!=0 ||
       delayed.raw_control.control_seq!=3 || delayed.raw_control.timestamp_ticks!=501000001 ||
       delayed.raw_control.point_handle!=slow_point || prompt.total_bytes!=32768 || prompt.total_events!=4096)
      $fatal(1,"automatic delayed collector must preserve raw totals, original-time windows/quality and release only all-ACKed data");
    $display("TB_PASS transport_growth frames=4096 delayed_bytes=65520 delayed_events=8190 prompt_checks=20 delayed_checks=20");$finish;
  end
  initial begin
    wait(monitor_ready);#500000000;
    control.control_seq=2;control.timestamp_ticks=$time;control.reset_n=1'bx;publish_control(slow_source,control);
    #1000000;control.control_seq=3;control.timestamp_ticks=$time;control.reset_n=1;publish_control(slow_source,control);
  end
  task automatic verify_prompt();
    prompt_checks++;
    if(prompt.result_seq!=prompt_checks || prompt.window_bytes!=1600 || prompt.window_events!=200 ||
       !prompt.window_valid || !prompt.bytes_complete || !prompt.events_complete)
      $fatal(1,"prompt group every-window literal rate must remain independent of other consumer backlog");
  endtask
  task automatic verify_delayed();
    bw_u64_t expected_bytes,expected_events;
    delayed_checks++;expected_bytes=(delayed_checks==6) ? 3184 : 3200;expected_events=(delayed_checks==6) ? 398 : 400;
    if(delayed.result_seq!=delayed_checks || delayed.window_end_ticks!=bw_u64_t'(delayed_checks)*100000000 ||
       delayed.window_bytes!=expected_bytes || delayed.window_events!=expected_events ||
       delayed.bytes_complete!=(delayed_checks!=6) || delayed.events_complete!=(delayed_checks!=6) ||
       delayed.window_valid!=(delayed_checks!=6) || delayed.member_reset_coverage)
      $fatal(1,"delayed original-time window%0d must keep known subtotals and only the actual unknown interval",delayed_checks);
  endtask
endmodule
program transport_growth_checker;
  initial forever begin @(tb_transport_growth.prompt.result_seq);if(tb_transport_growth.prompt.result_seq!=0)tb_transport_growth.verify_prompt();end
  initial forever begin @(tb_transport_growth.delayed.result_seq);if(tb_transport_growth.delayed.result_seq!=0)tb_transport_growth.verify_delayed();end
endprogram
