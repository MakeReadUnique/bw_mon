module tb_group_deferred_final;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,sentinel_valid=1;
  bit late=0,deliver=0,deliver_second=0;
  int point_handle,source;
  bw_record_t frame;
  bw_control_t control;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("sentinel"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(8),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(10)) sentinel
    (.clk(clk),.reset_n(1'b1),.valid(sentinel_valid));
  bw_point_mon #(.POINT_ID("stalled"),.PROTOCOL(BW_VALID_READY),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),
    .BACKPRESSURE_THRESHOLD(10)) stalled
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.ready(1'b0));
  bw_group_mon #(.GROUP_ID("deferred.g"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  always @(deliver)if(deliver)deliver_second<=1;
  always @(deliver_second)if(deliver_second)publish_frame(source,frame);
  initial begin
    void'($value$plusargs("LATE=%d",late));
    add_point_member("deferred.g","fault");
    point_handle=register_point("fault","controlled.fault",BW_NS,1,1);
    source=point_source_handle(point_handle);wait(monitor_ready);
    control='0;control.control_seq=1;control.point_handle=point_handle;control.reset_n=1;control.timestamp_ticks=measurement_start_ticks;
    publish_control(source,control);
    frame='0;frame.timestamp_ticks=measurement_start_ticks+250000;frame.record_seq=1;frame.edge_index=1;
    frame.byte_inc=32;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    #250000;clk=1;if(late)deliver<=1;#1;clk=0;sentinel_valid=0;
    if(scope_disabled(BW_GROUP,"deferred.g")==late || scope_disabled(BW_POINT,"sentinel") || scope_disabled(BW_POINT,"stalled"))
      $fatal(1,"same-time closure must isolate only missing group");
    #999999;if(!late)publish_frame(source,frame);
    #750001;
    if(core_failure_pending() || core_failure_seen || group_mon.accepted_record_seq!=(late?1:0))
      $fatal(1,"same-time success or sticky late rejection differs");
    $display("TB_PASS group_deferred_final late=%0b healthy_continues=1",late);$finish;
  end
  final begin
    if(core_failure_pending())$display("DEFERRED_FINAL_GUARD pending=1 seen=%0b",core_failure_seen);
    else $display("DEFERRED_FINAL_GUARD_CLEAR");
  end
endmodule
