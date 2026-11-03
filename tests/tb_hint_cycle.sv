module tb_hint_cycle;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,ready=0;
  bw_u64_t held_seq;
  bw_mon_setup setup();
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_CYCLE),.BACKPRESSURE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(reset_n),.valid(1'b1),.ready(ready));
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1)) disabled
    (.clk(clk),.reset_n(reset_n),.valid(1'b1),.ready(ready));
  bw_point_mon #(.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),.BACKPRESSURE_ENABLE(1)) unsupported
    (.clk(clk),.reset_n(reset_n),.valid(1'b0));
  task automatic edge_at(bw_u64_t at_ticks,bit release_now=0);
    #(at_ticks+1-$time);clk=1;if(release_now) ready<=1;#1;clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    edge_at(1000000);
    if(point.backpressure_duration_cycles!=0 || !point.backpressure_cycle_anchor_valid ||
       point.backpressure_start_cycle!=1) $fatal(1,"first edge anchors, rather than completes, a local cycle");
    edge_at(2000000);held_seq=point.backpressure_result_seq;
    if(point.backpressure_duration_cycles!=1 || point.backpressure_hit)
      $fatal(1,"one completed cycle cannot meet a two-cycle threshold");
    #7999998;
    if(point.backpressure_result_seq!=held_seq || point.backpressure_duration_cycles!=1 || point.backpressure_hit)
      $fatal(1,"cycle duration and sequence must hold while clock is stopped despite ns window publications");
    edge_at(10000000,1);
    if(!point.backpressure_hit || point.backpressure_active || point.backpressure_duration_cycles!=2 ||
       point.backpressure_trigger_ticks!=10000001 || point.backpressure_end_reason!=BW_HINT_RELEASED ||
       point.backpressure_start_cycle!=1 || point.backpressure_end_cycle!=3)
      $fatal(1,"same-edge release must first count completed prior cycle even before recorder ReNBA notification");
    #(10500002-$time);ready=0;
    edge_at(11000000);
    if(point.backpressure_duration_cycles!=0 || point.backpressure_start_cycle!=4)
      $fatal(1,"mid-cycle start must wait for next edge anchor");
    edge_at(12000000);
    #(12500002-$time);ready=1'bx;#1;
    if(point.backpressure_active || point.backpressure_duration_cycles!=1 || point.backpressure_hit ||
       point.backpressure_end_reason!=BW_HINT_UNKNOWN) $fatal(1,"unknown must break cycle evidence");
    #(13000002-$time);ready=0;clk=1;#1;clk=0;
    #(14000002-$time);clk=1;reset_n<=0;#1;clk=0;
    if(point.backpressure_active || point.backpressure_duration_cycles!=1 || point.backpressure_hit ||
       point.backpressure_hit_count!=1 || point.backpressure_end_reason!=BW_HINT_RESET)
      $fatal(1,"cycle intervals cannot join across unknown/reset");
    if(disabled.backpressure_active || disabled.backpressure_hit_count!=0 || disabled.backpressure_enabled ||
       !disabled.backpressure_supported || unsupported.backpressure_supported || !unsupported.backpressure_enabled ||
       unsupported.backpressure_interval_count!=0 || point.total_bytes!=disabled.total_bytes)
      $fatal(1,"capability/enable and hint activity must remain separate from raw accounting");
    $display("TB_PASS hint_cycle");$finish;
  end
endmodule
