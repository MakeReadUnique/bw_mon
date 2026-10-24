module tb_hint_ns;
  timeunit 1ns;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic reset_n=1,ready=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(2)) point
    (.clk(1'b0),.reset_n(reset_n),.valid(1'b1),.ready(ready));
  initial begin
    wait(monitor_ready);
    #1999999fs;
    if(!point.backpressure_active || point.backpressure_hit || point.backpressure_start_ticks!=0)
      $fatal(1,"stopped-clock ns interval must start from live known condition");
    #2fs;
    if(!point.backpressure_hit || point.backpressure_trigger_ticks!=2000000 ||
       point.backpressure_hit_count!=1 || point.backpressure_duration_ticks!=2000000)
      $fatal(1,"ns threshold must trigger once with no sampling clocks");
    #999999fs;ready=1;#1fs;
    if(point.backpressure_active || point.backpressure_end_reason!=BW_HINT_RELEASED ||
       point.backpressure_duration_ticks!=3000000 || point.backpressure_interval_count!=1)
      $fatal(1,"live release must close stopped-clock interval at actual time");
    #999999fs;ready=0;#1ns;ready=1'bx;#1fs;
    if(point.backpressure_active || point.backpressure_trusted || point.backpressure_hit ||
       point.backpressure_end_reason!=BW_HINT_UNKNOWN || point.backpressure_duration_ticks!=1000000)
      $fatal(1,"unknown raw handshake must interrupt and cannot reuse old snapshot");
    #499999fs;ready=0;#500000fs;reset_n=0;#1fs;
    if(point.backpressure_active || point.backpressure_end_reason!=BW_HINT_RESET ||
       point.backpressure_duration_ticks!=500000 || point.backpressure_hit_count!=1)
      $fatal(1,"reset must interrupt without joining evidence across the unknown gap");
    #499999fs;reset_n=1;
    #2000001fs;
    if(!point.backpressure_hit || point.backpressure_hit_count!=2 ||
       point.backpressure_trigger_ticks!=8500000 || point.total_events!=0)
      $fatal(1,"reset release starts independent interval, diagnostics do not invent transfers");
    #499999fs;
    $display("TB_PASS hint_ns");$finish;
  end
endmodule
