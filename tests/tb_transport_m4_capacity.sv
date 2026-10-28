// Frozen old M4 cursor/count oracle at the record-storage component seam.
// Every frame is really published at its own time; no counters are preloaded.
module tb_transport_m4_capacity;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  int point,source,groups[16];
  bw_record_t frame,readback;
  bw_control_t control;
  bw_control_frame_t envelope;
  bw_mon_setup setup();
  initial begin
    for(int g=0;g<16;g++)begin
      add_point_member($sformatf("g%0d",g),"p");
      groups[g]=register_group_owner($sformatf("g%0d",g),$sformatf("component.g%0d",g),BW_CYCLE,16,1);
    end
    point=register_point("p","component.point",BW_CYCLE,16,1);source=point_source_handle(point);wait(monitor_ready);
    control='0;control.point_handle=point;control.control_seq=1;control.reset_n=1;control.timestamp_ticks=$time;publish_control(source,control);
    for(int g=0;g<16;g++)acknowledge_member_control(groups[g],0,1);
    for(int i=1;i<=204;i++)begin
      #500000;
      if(i==199 || i==201)begin
        control.control_seq=(i==199)?2:3;control.reset_n=(i==199)?0:1;control.source_epoch=1;control.timestamp_ticks=$time;publish_control(source,control);
        for(int g=0;g<15;g++)begin void'(peek_member_control(groups[g],0,envelope));acknowledge_member_control(groups[g],0,envelope.transport_seq);end
      end
      frame='0;frame.timestamp_ticks=$time;frame.edge_index=i;frame.record_seq=i;frame.source_epoch=(i>=199)?1:0;
      frame.byte_inc=(i%2)?8:16;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
      publish_frame(source,frame);
      if(i==204 && (retained_frame_count(source)!=6 || bw_test_storage_peak["transport.frames"]!=6))$fatal(1,"literal M4 allocator prefix peak6 differs");
      for(int g=0;g<15;g++)acknowledge_member_frame(groups[g],0,i);
      if(i<=198)acknowledge_member_frame(groups[15],0,i);
      if(i==203)begin
        if(acknowledged_frame_seq(groups[0],0)!=203 || acknowledged_frame_seq(groups[15],0)!=198 || retained_frame_count(source)!=5 || retained_control_count(source)!=2)
          $fatal(1,"literal M4 fast203/slow198 five-frame two-control capacity differs");
        $display("TB_M4_COMPONENT fast_ack=203 slow_ack=198 retained_frames=5 retained_controls=2 consumers=16");
      end
    end
    for(int i=199;i<=204;i++)begin
      if(!peek_member_frame(groups[15],0,readback) || readback.record_seq!=i || readback.timestamp_ticks!=measurement_start_ticks+bw_u64_t'(i)*500000 || readback.byte_inc!=((i%2)?8:16))$fatal(1,"M4 component retained original identity differs");
      acknowledge_member_frame(groups[15],0,i);
    end
    for(int c=2;c<=3;c++)begin
      if(!peek_member_control(groups[15],0,envelope) || envelope.value.control_seq!=c || envelope.value.timestamp_ticks!=measurement_start_ticks+((c==2)?99500000:100500000))$fatal(1,"M4 component control origin differs");
      acknowledge_member_control(groups[15],0,envelope.transport_seq);
    end
    if(acknowledged_frame_seq(groups[15],0)!=204 || retained_frame_count(source)!=0 || retained_control_count(source)!=0)$fatal(1,"M4 component exact204 release differs");
    $display("TB_PASS transport_m4_capacity scope=storage_component actual_records=204 fast=203 slow=198 frames=5 controls=2 allocator_peak=6 release_ack=204 release=0");$finish;
  end
endmodule
