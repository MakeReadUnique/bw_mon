module tb_transport_retention;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  int point_handle,source,first,second;
  bw_record_t frame,received;
  bw_control_t control;
  bw_control_frame_t received_control;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1),.EXPECTED_GROUP_COUNT(2)) setup();
  initial begin
    define_group("first",1);add_point_member("first","p");
    define_group("second",1);add_point_member("second","p");
    first=register_group_owner("first","component.first",BW_NS,1,1,"clk");
    second=register_group_owner("second","component.second",BW_NS,1,1,"clk");
    point_handle=register_point("p","component.point",BW_NS,1,1,"clk");
    source=point_source_handle(point_handle);finish_configuration();wait(monitor_ready);
    control='0;control.point_handle=point_handle;control.control_seq=1;control.reset_n=1;
    publish_control(source,control);
    if(!peek_member_control(first,0,received_control))$fatal(1,"initial control missing");
    acknowledge_member_control(first,0,received_control.transport_seq);
    if(retained_control_count(source)!=1)$fatal(1,"slow second consumer must retain the original control");
    #250000;
    frame='0;frame.record_seq=1;frame.edge_index=1;frame.timestamp_ticks=$time;
    frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    publish_frame(source,frame);
    if(!peek_member_frame(first,0,received) || received.byte_inc!=8)$fatal(1,"first frame missing");
    acknowledge_member_frame(first,0,1);
    if(retained_frame_count(source)!=1 || acknowledged_frame_seq(second,0)!=0)
      $fatal(1,"one acknowledgement must not release another direct consumer's frame");
    #250000;
    control.control_seq=2;control.source_epoch=1;control.reset_n=0;control.timestamp_ticks=$time;
    publish_control(source,control);
    if(!peek_member_control(first,0,received_control) || received_control.value.control_seq!=2)
      $fatal(1,"fast consumer must advance through package-owned control positions");
    acknowledge_member_control(first,0,received_control.transport_seq);
    #250000;
    frame.record_seq=2;frame.edge_index=2;frame.timestamp_ticks=$time;frame.source_epoch=1;
    frame.byte_inc=0;frame.event_inc=0;frame.reset_points=1;frame.reset_n=0;
    publish_frame(source,frame);
    if(!peek_member_frame(first,0,received) || received.record_seq!=2 || !received.bytes_complete)
      $fatal(1,"known reset frame must remain complete and ordered");
    if(!peek_member_frame(first,0,received) || received.record_seq!=2)
      $fatal(1,"querying does not advance the authoritative consumer position");
    acknowledge_member_frame(first,0,2);
    if(retained_frame_count(source)!=2 || !peek_member_frame(second,0,received) ||
       received.record_seq!=1 || received.timestamp_ticks!=250000 || received.byte_inc!=8)
      $fatal(1,"slow consumer must still read the original first record");
    acknowledge_member_frame(second,0,1);
    if(retained_frame_count(source)!=1 || !peek_member_frame(second,0,received) ||
       received.record_seq!=2 || received.source_epoch!=1 || received.reset_points!=1)
      $fatal(1,"release must follow the minimum of all direct-consumer acknowledgements");
    acknowledge_member_frame(second,0,2);
    if(retained_frame_count(source)!=0)$fatal(1,"all acknowledged frames must be reclaimed");
    if(!peek_member_control(second,0,received_control) || received_control.value.control_seq!=1)
      $fatal(1,"slow consumer lost initial reset state");
    acknowledge_member_control(second,0,received_control.transport_seq);
    if(!peek_member_control(second,0,received_control) || received_control.value.control_seq!=2 ||
       received_control.value.timestamp_ticks!=500000 || received_control.value.reset_n!==1'b0)
      $fatal(1,"slow consumer lost original reset control timestamp/state");
    acknowledge_member_control(second,0,received_control.transport_seq);
    if(retained_control_count(source)!=0)$fatal(1,"all acknowledged controls must be reclaimed");
    #250000;
    control.control_seq=3;control.reset_n=1;control.timestamp_ticks=$time;
    publish_control(source,control);
    for(int g=0;g<2;g++)begin
      if(!peek_member_control(g,0,received_control))$fatal(1,"release control missing");
      acknowledge_member_control(g,0,received_control.transport_seq);
    end
    #250000;
    frame.record_seq=3;frame.edge_index=3;frame.timestamp_ticks=$time;
    frame.reset_points=0;frame.reset_n=1;frame.event_inc=1;frame.byte_inc=0;
    publish_frame(source,frame);
    for(int g=0;g<2;g++)begin
      if(!peek_member_frame(g,0,received) || received.event_inc!=1 || received.byte_inc!=0)
        $fatal(1,"zero-byte activity must remain a real retained event");
      acknowledge_member_frame(g,0,3);
    end
    if(retained_frame_count(source)!=0 || retained_control_count(source)!=0)
      $fatal(1,"automatic reclamation did not follow complete consumption");
    $display("TB_PASS transport_retention");$finish;
  end
endmodule
