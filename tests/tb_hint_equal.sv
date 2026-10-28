module tb_hint_equal;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic release_ready=0,unknown_ready=0,reset_n=1;
  bw_mon_setup setup();
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(2)) released
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b1),.ready(release_ready));
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(2)) unknown
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b1),.ready(unknown_ready));
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(2)) reset_point
    (.clk(1'b0),.reset_n(reset_n),.valid(1'b1),.ready(1'b0));
  initial begin
    wait(monitor_ready);
    #2000000;release_ready=1;unknown_ready=1'bx;reset_n=0;#1;
    if(!released.backpressure_hit || !unknown.backpressure_hit || !reset_point.backpressure_hit ||
       released.backpressure_active || unknown.backpressure_active || reset_point.backpressure_active ||
       released.backpressure_trigger_ticks!=2000001 || unknown.backpressure_trigger_ticks!=2000001 ||
       reset_point.backpressure_trigger_ticks!=2000000 || released.backpressure_duration_ticks!=2000000 ||
       unknown.backpressure_duration_ticks!=2000000 || reset_point.backpressure_duration_ticks!=2000000)
      $fatal(1,"threshold-equal release/unknown/reset must settle previous known [0,2) duration and retain hit");
    if(released.backpressure_end_reason!=BW_HINT_RELEASED || unknown.backpressure_end_reason!=BW_HINT_UNKNOWN ||
       reset_point.backpressure_end_reason!=BW_HINT_RESET)
      $fatal(1,"end reasons must distinguish release, unknown and reset");
    #5000000;
    if(released.backpressure_hit_count!=1 || unknown.backpressure_hit_count!=1 || reset_point.backpressure_hit_count!=1)
      $fatal(1,"ended intervals cannot retrigger from stale ns timer or held snapshot");
    $display("TB_PASS hint_equal");$finish;
  end
endmodule
