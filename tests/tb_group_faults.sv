module tb_group_faults;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  int point_handle,source;
  string mode;
  bw_record_t frame,replayed;
  bw_control_t control;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("good"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(8)) good
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("fault.group"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial begin
    if(!$value$plusargs("MODE=%s",mode))$fatal(1,"MODE required");
    add_point_member("fault.group","fault");add_point_member("fault.group","good");
    point_handle=register_point("fault","controlled.fault",BW_NS,1,1);
    source=point_source_handle(point_handle);wait(monitor_ready);
    control='0;control.control_seq=1;control.point_handle=point_handle;control.reset_n=1;control.timestamp_ticks=measurement_start_ticks;
    publish_control(source,control);
    frame='0;frame.timestamp_ticks=measurement_start_ticks+250000;frame.record_seq=1;frame.edge_index=1;
    frame.byte_inc=32;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    #250000;clk=1;
    if(mode!="missing_first")begin
      if(mode=="record_gap")frame.record_seq=2;
      if(mode=="wrong_edge")frame.edge_index=2;
      if(mode=="wrong_time")frame.timestamp_ticks=measurement_start_ticks+250001;
      publish_frame(source,frame);
      if(mode=="duplicate")publish_frame(source,frame);
    end
    #1;clk=0;
    if(mode=="missing_second" || mode=="reverse")begin
      #499999;clk=1;
      if(mode=="reverse")begin
        replayed=frame;frame.record_seq=2;frame.edge_index=2;frame.timestamp_ticks=measurement_start_ticks+750000;
        publish_frame(source,frame);publish_frame(source,replayed);
      end
    end
    #(measurement_start_ticks+2000000-$time);
    if(!scope_disabled(BW_GROUP,"fault.group") || scope_disabled(BW_POINT,"good") ||
       (!(mode inside {"missing_first","missing_second","wrong_time"}) && !scope_disabled(BW_POINT,"fault")))
      $fatal(1,"bad source/consumer ordering must disable its typed dependency path while healthy point continues");
    $display("TB_PASS group_faults runtime_warning mode=%s healthy_point=1",mode);$finish;
  end
endmodule
