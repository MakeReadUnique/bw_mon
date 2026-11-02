module tb_settle_notification_owner;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  int point_handle,source;
  bw_record_t frame;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("healthy"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(16))
    healthy(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("receiver"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2))
    receiver(.clk(1'b0),.reset_n(1'b1));
  import "DPI-C" context function int bw_test_observe_group_completion();
  function void bw_test_group_completion_observed();
    if($time!=1000001 || !scope_disabled(BW_GROUP,"receiver") ||
       scope_disabled(BW_POINT,"producer") || scope_disabled(BW_POINT,"healthy") ||
       receiver.accepted_record_seq!=0 || acknowledged_frame_seq(receiver.group_handle,0)!=0 ||
       healthy.total_bytes!=16 || !point_batch_complete("healthy") || monitoring_failure_count!=1)
      $fatal(1,"an unrelated pending callback must not hide a new receiver's audit responsibility");
    $display("TB_PASS settle_notification_owner original_ticks=%0d healthy_bytes=16 receiver_accepted=0",$time);
    $finish;
  endfunction
  export "DPI-C" function bw_test_group_completion_observed;
  initial begin
    point_handle=register_point("producer","controlled.producer",BW_CYCLE,2,2);
    source=point_source_handle(point_handle);add_point_member("receiver","producer");
    wait(monitor_ready);#1000000;clk=1;
    // The healthy edge posts a real grant first. The receiver has no actual
    // edge, so only its input notification can schedule the unexpected-frame
    // audit. Observe the verdict at this same original timestamp.
    #0;frame='0;frame.timestamp_ticks=$time;frame.edge_index=1;frame.record_seq=1;
    frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    publish_frame(source,frame);
    if(!bw_test_observe_group_completion())$fatal(1,"cannot register receiver nativeRO verifier");
  end
endmodule
