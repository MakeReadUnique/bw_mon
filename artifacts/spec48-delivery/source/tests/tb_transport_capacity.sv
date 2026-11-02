// Existing transport component seam only: manual consumers demonstrate queue
// capacity and cursor identity; this is not a public group completion scenario.
module tb_transport_capacity;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  int point,source,fast,slow;
  bw_record_t frame,readback;
  bw_control_t control;
  bw_control_frame_t envelope;
  bw_mon_setup setup();
  initial begin
    add_point_member("fast","p");add_point_member("slow","p");
    fast=register_group_owner("fast","component.fast",BW_CYCLE,2,2);
    slow=register_group_owner("slow","component.slow",BW_CYCLE,2,2);
    point=register_point("p","component.source",BW_CYCLE,2,2);source=point_source_handle(point);
    wait(monitor_ready);
    control='0;control.point_handle=point;control.timestamp_ticks=$time;control.control_seq=1;control.reset_n=1;
    publish_control(source,control);
    for(int g=0;g<2;g++)begin void'(peek_member_control(g,0,envelope));acknowledge_member_control(g,0,envelope.transport_seq);end
    // Two distinct control identities at one physical time, no expired input.
    control.control_seq=2;control.reset_n=0;control.source_epoch=1;publish_control(source,control);
    control.control_seq=3;control.reset_n=1;publish_control(source,control);
    for(int c=0;c<2;c++)begin void'(peek_member_control(fast,0,envelope));acknowledge_member_control(fast,0,envelope.transport_seq);end
    if(retained_control_count(source)!=2)$fatal(1,"component two-control retention missing");
    for(int i=1;i<=4096;i++)begin
      #500000;frame='0;frame.timestamp_ticks=$time;frame.edge_index=i;frame.record_seq=i;
      frame.source_epoch=1;frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
      publish_frame(source,frame);acknowledge_member_frame(fast,0,i);
      if(i==5 && retained_frame_count(source)!=5)$fatal(1,"component five-frame retention missing");
      if(i==6 && retained_frame_count(source)!=6)$fatal(1,"component allocator six-entry growth missing");
    end
    if(retained_frame_count(source)!=4096 || acknowledged_frame_seq(fast,0)!=4096 || acknowledged_frame_seq(slow,0)!=0)
      $fatal(1,"component4096 original records were not retained independently of prompt cursor");
    for(int i=1;i<=4096;i++)begin
      if(!peek_member_frame(slow,0,readback) || readback.record_seq!=i || readback.edge_index!=i ||
         readback.timestamp_ticks!=measurement_start_ticks+bw_u64_t'(i)*500000 || readback.byte_inc!=8 || readback.event_inc!=1)
        $fatal(1,"component original record identity differs at%0d",i);
      acknowledge_member_frame(slow,0,i);
    end
    for(int c=2;c<=3;c++)begin
      if(!peek_member_control(slow,0,envelope) || envelope.value.control_seq!=c || envelope.value.timestamp_ticks!=measurement_start_ticks)
        $fatal(1,"component original control identity differs");
      acknowledge_member_control(slow,0,envelope.transport_seq);
    end
    if(retained_frame_count(source)!=0 || retained_control_count(source)!=0)$fatal(1,"component all-effective-ACK release failed");
    $display("TB_PASS transport_capacity scope=component retained_peak=4096 fast_ack=4096 slow_before=0 five=5 allocator_six=6 controls=2 release=0");$finish;
  end
endmodule
