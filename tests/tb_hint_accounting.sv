module tb_hint_accounting;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1,ready=0;
  bw_mon_setup setup();
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.FIXED_BYTES(8),.WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(3),.UPDATE_STRIDE(1),.BACKPRESSURE_ENABLE(1),
    .BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(2)) enabled
    (.clk(clk),.reset_n(1'b1),.valid(valid),.ready(ready));
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.FIXED_BYTES(8),.WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(3),.UPDATE_STRIDE(1)) disabled
    (.clk(clk),.reset_n(1'b1),.valid(valid),.ready(ready));
  initial begin
    wait(monitor_ready);
    #2000001;
    if(!enabled.backpressure_hit || enabled.result_seq!=0)
      $fatal(1,"ns hint threshold is independent of cycle window and first sampling edge");
    #999999;ready=1;clk=1;#1;clk=0;
    #999999;clk=1;#1;clk=0;
    #999999;clk=1;#1;clk=0;
    #999999;valid=0;clk=1;#1;
    if(enabled.total_bytes!=24 || disabled.total_bytes!=24 || enabled.total_events!=3 ||
       disabled.total_events!=3 || enabled.window_bytes!=24 || disabled.window_bytes!=24 ||
       !enabled.window_full || !disabled.window_full || enabled.bandwidth_gbps!=8.0 ||
       disabled.bandwidth_gbps!=8.0 || enabled.bytes_per_cycle!=8.0 ||
       enabled.backpressure_interval_count!=1 || enabled.backpressure_hit_count!=1 ||
       disabled.backpressure_hit_count!=0 || enabled.backpressure_end_ticks!=3000001)
      $fatal(1,"enabled hint must preserve identical positive raw transfer/window results and its own independent interval result");
    $display("TB_PASS hint_accounting");$finish;
  end
endmodule
