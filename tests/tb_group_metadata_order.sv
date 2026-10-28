module tb_group_metadata_order;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bit reactive_clock=0;
  int point_handle,source;
  bw_record_t frame;
  bw_control_t control;
  bw_mon_setup setup();
  bw_group_mon #(.GROUP_ID("metadata"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  group_metadata_late_clock late_clock();
  initial begin
    void'($value$plusargs("REACTIVE_CLOCK=%d",reactive_clock));
    add_point_member("metadata","p");
    point_handle=register_point("p","controlled.point",BW_NS,1,1);
    source=point_source_handle(point_handle);wait(monitor_ready);
    control='0;control.control_seq=1;control.point_handle=point_handle;control.reset_n=1;control.timestamp_ticks=measurement_start_ticks;
    publish_control(source,control);
    #250000;
    // Same physical sampling T: data is available in Active, receiver clock
    // metadata arrives through NBA. Neither ordering invents a missing edge.
    if(!reactive_clock)clk<=1;
    frame='0;frame.timestamp_ticks=$time;frame.record_seq=1;frame.edge_index=1;
    frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    publish_frame(source,frame);
    #1;clk=0;
    if(group_mon.accepted_record_seq!=1 || group_mon.raw_record.timestamp_ticks!=measurement_start_ticks+250000 ||
       group_mon.raw_record.edge_index!=1 || group_mon.raw_record.byte_inc!=8)
      $fatal(1,"later same-T clock metadata must still match and accept the source frame");
    #750000;
    if(group_mon.window_bytes!=8 || group_mon.window_end_ticks!=measurement_start_ticks+1000000 || !group_mon.window_valid)
      $fatal(1,"same-T scheduling must not change the independently expected window");
    $display("TB_PASS group_metadata_order");$finish;
  end
endmodule

program group_metadata_late_clock;
  timeunit 1fs;timeprecision 1fs;
  initial begin
    wait(tb_group_metadata_order.reactive_clock);
    wait(bw_mon_pkg::monitor_ready);
    #250000;tb_group_metadata_order.clk<=1;
  end
endprogram
