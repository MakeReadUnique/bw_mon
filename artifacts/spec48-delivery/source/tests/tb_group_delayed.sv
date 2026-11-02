module tb_group_delayed;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bit deliver=0,deliver_second=0;
  int point_handle,transport_source;
  bw_record_t slow_frame;
  bw_control_t initial_control;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("fast"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(8)) fast
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("delayed"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  always @(deliver) if (deliver) deliver_second<=1;
  always @(deliver_second) if (deliver_second) publish_frame(transport_source,slow_frame);
  initial begin
    add_point_member("delayed","slow");add_point_member("delayed","fast");
    point_handle=register_point("slow","controlled.source",BW_NS,1,1);
    transport_source=point_source_handle(point_handle);
    wait(monitor_ready);
    initial_control='0;initial_control.point_handle=point_handle;initial_control.control_seq=1;
    initial_control.reset_n=1;initial_control.timestamp_ticks=measurement_start_ticks;
    publish_control(transport_source,initial_control);
    slow_frame='0;slow_frame.record_seq=1;slow_frame.edge_index=1;
    slow_frame.timestamp_ticks=measurement_start_ticks+250000;slow_frame.byte_inc=32;slow_frame.event_inc=1;
    slow_frame.bytes_complete=1;slow_frame.events_complete=1;slow_frame.reset_n=1;
    #250000;clk=1;deliver<=1;#1;clk=0;
    #(measurement_start_ticks+1250001-$time);
    if (group_mon.raw_record.timestamp_ticks!=250001 || group_mon.raw_record.edge_index!=1 ||
        group_mon.raw_record.byte_inc!=40 || group_mon.accepted_record_seq!=1 ||
        group_mon.result_seq!=1 || group_mon.window_end_ticks!=1000001 ||
        group_mon.window_bytes!=40 || !group_mon.window_valid ||
        $abs(group_mon.bandwidth_gbps-40.0)>1e-10)
      $fatal(1,"same-time NBA arrival must produce the original logical window after complete input");
    #750000;
    if (group_mon.result_seq!=2 || group_mon.window_end_ticks!=2000001 ||
        group_mon.window_bytes!=0 || !group_mon.window_valid)
      $fatal(1,"a legal stopped clock creates no missing frames and ns history expires normally");
    $display("TB_PASS group_delayed");$finish;
  end
endmodule
