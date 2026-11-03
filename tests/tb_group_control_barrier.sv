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
  always @(group_mon.accepted_record_seq)if(group_mon.accepted_record_seq!=0 &&
    (group_mon.accepted_control_count!=3 || group_mon.raw_control.control_seq!=3 || group_mon.raw_control.timestamp_ticks!=measurement_start_ticks+500000))
      $fatal(1,"frame core receipt preceded its exact earlier control prefix");
  initial begin
    add_point_member("timeline","p");
    point_handle=register_point("p","controlled.point",BW_NS,1,1);
    source=point_source_handle(point_handle);wait(monitor_ready);
    control='0;control.control_seq=1;control.point_handle=point_handle;control.reset_n=1;control.timestamp_ticks=measurement_start_ticks;
    publish_control(source,control);
    // Preserve the original gap[0.25,0.5)ns and frame at0.75ns. Each
    // control is now supplied at its actual original time, rather than old
    // data being delivered successfully after a later sampling edge.
    #250000;control.control_seq=2;control.timestamp_ticks=$time;control.reset_n=1'bx;
    publish_control(source,control);set_source_progress(source,$time);
    #250000;control.control_seq=3;control.timestamp_ticks=$time;control.reset_n=1;
    publish_control(source,control);set_source_progress(source,BW_U64_MAX);
    #250000;clk=1;
    frame='0;frame.timestamp_ticks=$time;frame.record_seq=1;frame.edge_index=1;
    frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    publish_frame(source,frame);
    #1;clk=0;
    if(group_mon.accepted_record_seq!=1 || group_mon.accepted_control_count!=3)
      $fatal(1,"all original-time control prefix receipts must precede the later frame receipt");
    #(measurement_start_ticks+1250001-$time);
    if(group_mon.accepted_control_count!=3 || group_mon.accepted_record_seq!=1 ||
       group_mon.result_seq!=1 || group_mon.window_end_ticks!=measurement_start_ticks+1000000 || group_mon.window_bytes!=8 ||
       group_mon.bytes_complete || group_mon.events_complete || group_mon.window_valid)
      $fatal(1,"control prefix must be processed before the original-time frame/window");
    $display("TB_PASS group_control_barrier");$finish;
  end
endmodule
