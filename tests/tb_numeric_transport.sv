module tb_numeric_transport;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  string mode;
  int point_handle,source,group_handle;
  bw_record_t frame,received;
  bw_control_t control;
  bw_control_frame_t envelope;
  bit found;
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="ack_frame";
    add_point_member("transport.group","transport.point");
    group_handle=register_group_owner("transport.group","component.group",BW_NS,1,1);
    point_handle=register_point("transport.point","component.point",BW_NS,1,1);
    source=point_source_handle(point_handle);wait(monitor_ready);
    #250000;
    frame='0;frame.timestamp_ticks=$time;frame.edge_index=1;frame.record_seq=1;
    frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    control='0;control.point_handle=point_handle;control.timestamp_ticks=$time;control.control_seq=1;control.reset_n=1'bz;
    if(mode=="publish_handle")publish_frame(64'hx000000000000000,frame);
    else begin
      publish_frame(source,frame);publish_control(source,control);
      if(mode=="ack_frame")acknowledge_member_frame(group_handle,0,64'hx000000000000001);
      else if(mode=="ack_control")acknowledge_member_control(group_handle,0,64'hx000000000000001);
      else if(mode=="group_handle")found=peek_member_frame(64'hx000000000000000,0,received);
      else if(mode=="member_index")found=peek_member_frame(group_handle,64'hx000000000000000,received);
      else if(mode=="progress")set_source_progress(source,64'hx000000000000000);
      else if(mode=="valid_reset")begin
        if(!peek_member_control(group_handle,0,envelope) || envelope.value.reset_n!==1'bz ||
           !peek_member_frame(group_handle,0,received) || received.byte_inc!=8)
          $fatal(1,"four-state reset is legitimate quality, independently of numeric metadata");
        acknowledge_member_control(group_handle,0,1);acknowledge_member_frame(group_handle,0,1);
        $display("TB_PASS numeric_transport valid_reset");$finish;
      end else $fatal(1,"bad MODE");
    end
    if(mode=="progress")begin
      if(!scope_disabled(BW_POINT,"transport.point"))$fatal(1,"invalid source progress must disable its source");
    end else if(!monitoring_shared_disabled)$fatal(1,"invalid unowned transport handle must disable shared monitoring");
    if(mode!="publish_handle" && (retained_frame_count(source)!=1 || retained_control_count(source)!=1 ||
       acknowledged_frame_seq(group_handle,0)!=0))
      $fatal(1,"rejected numeric transport operation must not ACK or release durable data");
    $display("TB_PASS numeric_transport quarantined mode=%s",mode);$finish;
  end
endmodule
