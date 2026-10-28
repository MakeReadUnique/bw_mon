module tb_group_control_barrier;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  int point_handle,source;
  bw_record_t frame;
  bw_control_t control;
  bw_mon_setup setup();
  bw_group_mon #(.GROUP_ID("timeline"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial begin
    add_point_member("timeline","p");
    point_handle=register_point("p","controlled.point",BW_NS,1,1);
    source=point_source_handle(point_handle);wait(monitor_ready);
    control='0;control.control_seq=1;control.point_handle=point_handle;control.reset_n=1;control.timestamp_ticks=measurement_start_ticks;
    publish_control(source,control);
    #250000;set_source_progress(source,$time);
    #500000;clk=1;
    frame='0;frame.timestamp_ticks=$time;frame.record_seq=1;frame.edge_index=1;
    frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    publish_frame(source,frame);
    #1;clk=0;
    #250000;
    if(group_mon.accepted_record_seq!=0 || group_mon.result_seq!=0)
      $fatal(1,"a later frame must not enter the core before an announced earlier control prefix");
    #249999;
    control.control_seq=2;control.timestamp_ticks=measurement_start_ticks+250000;control.reset_n=1'bx;
    publish_control(source,control);
    control.control_seq=3;control.timestamp_ticks=measurement_start_ticks+500000;control.reset_n=1;
    publish_control(source,control);set_source_progress(source,BW_U64_MAX);
    #1;
    if(group_mon.accepted_control_count!=3 || group_mon.accepted_record_seq!=1 ||
       group_mon.result_seq!=1 || group_mon.window_end_ticks!=measurement_start_ticks+1000000 || group_mon.window_bytes!=8 ||
       group_mon.bytes_complete || group_mon.events_complete || group_mon.window_valid)
      $fatal(1,"control prefix must be processed before the original-time frame/window");
    $display("TB_PASS group_control_barrier");$finish;
  end
endmodule
