module tb_numeric_record_unknown;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  int point_handle,source;
  bw_record_t frame;
  bw_control_t control;
  string mode;
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="frame_bytes";
    point_handle=register_point("record.subject","component.record",BW_NS,1,1);
    source=point_source_handle(point_handle);configure_monitor(1);wait(monitor_ready);
    #250000;
    frame='0;frame.timestamp_ticks=$time;frame.edge_index=1;frame.record_seq=1;
    frame.byte_inc=1;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    control='0;control.point_handle=point_handle;control.timestamp_ticks=$time;control.control_seq=1;control.reset_n=1'bx;
    if(mode=="frame_bytes")frame.byte_inc=64'hx000000000000001;
    if(mode=="frame_ticks")frame.timestamp_ticks=64'hx00000000003d090;
    if(mode=="frame_sequence")frame.record_seq=64'hx000000000000001;
    if(mode=="control_sequence")control.control_seq=64'hx000000000000001;
    if(mode=="control_origin")control.point_handle=32'hx0000000;
    $display("NUMERIC_RECORD byte_unknown=%0b seq_unknown=%0b control_unknown=%0b",$isunknown(frame.byte_inc),$isunknown(frame.record_seq),$isunknown(control.control_seq));
    if(mode=="control_sequence" || mode=="control_origin")publish_control(source,control);
    else publish_frame(source,frame);
    $fatal(1,"expected core error did not occur");
  end
endmodule
