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
    control='0;control.control_seq=1;control.point_handle=point_handle;control.reset_n=1;
    publish_control(source,control);
    frame='0;frame.timestamp_ticks=250000;frame.record_seq=1;frame.edge_index=1;
    frame.byte_inc=32;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    #250000;clk=1;#1;clk=0;
    if(mode!="missing_first")begin
      if(mode=="record_gap")frame.record_seq=2;
      if(mode=="wrong_edge")frame.edge_index=2;
      if(mode=="wrong_time")frame.timestamp_ticks=250001;
      publish_frame(source,frame);
      if(mode=="duplicate")publish_frame(source,frame);
    end
    if(mode=="missing_second" || mode=="reverse")begin
      #499999;clk=1;#1;clk=0;
      if(mode=="reverse")begin
        replayed=frame;frame.record_seq=2;frame.edge_index=2;frame.timestamp_ticks=750000;
        publish_frame(source,frame);publish_frame(source,replayed);
      end
    end
    #(2000002-$time);$fatal(1,"expected core error did not occur");
  end
endmodule
