module tb_settle_hint_renba;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, ready=0;
  int mode=0;
  bit observed_raw_late_edge=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("preflight.hint.late_clock"),
    .PROTOCOL(BW_VALID_READY),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_CYCLE),
    .BACKPRESSURE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.ready(ready));
  settle_hint_renba_driver late_clock();
  initial begin
    void'($value$plusargs("MODE=%d",mode));
    if(!(mode inside {0,1})) $fatal(1,"unsupported probe mode");
    wait(monitor_ready);
    #1000000;clk=1;#1;clk=0;
    #999999;clk=1;#1;clk=0;
    #999999;
    if(mode==0)clk=1; // Control: edge metadata precedes module-NBA release.
    ready<=1;
    // All observation occurs at a strictly later physical time. No observer
    // samples an intermediate same-slot Active/NBA/Reactive/ReNBA state.
    #1;
    $display("PREFLIGHT_ACTUAL mode=%0d observe_ticks=%0d clk=%b ready=%b sampled_valid=%b sampled_ready=%b sampled_reset=%b raw_seq=%0d raw_ticks=%0d raw_event=%0d raw_bytes=%0d accepted_seq=%0d bytes=%0d events=%0d active=%0d hit=%0d hit_count=%0d interval_count=%0d interval_id=%0d result_seq=%0d duration_ticks=%0d cycles=%0d start_cycle=%0d end_cycle=%0d trigger=%0d end=%0d reason=%0d late_edge_scheduled=%0d",
      mode,$time,clk,ready,point.sampled_valid,point.sampled_ready,point.sampled_reset_n,
      point.raw_record.record_seq,point.raw_record.timestamp_ticks,point.raw_record.event_inc,point.raw_record.byte_inc,
      point.accepted_record_seq,point.total_bytes,point.total_events,point.backpressure_active,
      point.backpressure_hit,point.backpressure_hit_count,point.backpressure_interval_count,
      point.backpressure_interval_id,point.backpressure_result_seq,point.backpressure_duration_ticks,
      point.backpressure_duration_cycles,point.backpressure_start_cycle,point.backpressure_end_cycle,
      point.backpressure_trigger_ticks,point.backpressure_end_ticks,point.backpressure_end_reason,
      observed_raw_late_edge);
    if(point.accepted_record_seq!==64'd3 || point.raw_record.timestamp_ticks!==64'd3000000 ||
       point.sampled_valid!==1'b1 || point.sampled_ready!==(mode==1) || point.sampled_reset_n!==1'b1 ||
       point.total_bytes!==(mode==1 ? 64'd8 : 64'd0) || point.total_events!==(mode==1 ? 64'd1 : 64'd0) ||
       observed_raw_late_edge!==(mode==1))
      $fatal(1,"probe raw sampling did not match independently specified source ordering");
    if(point.backpressure_active!==1'b0 || point.backpressure_hit!==1'b1 ||
       point.backpressure_hit_count!==64'd1 || point.backpressure_interval_count!==64'd1 ||
       point.backpressure_duration_cycles!==64'd2 || point.backpressure_start_cycle!==64'd1 ||
       point.backpressure_end_cycle!==64'd3 || point.backpressure_trigger_ticks!==64'd3000000 ||
       point.backpressure_end_ticks!==64'd3000000 || point.backpressure_end_reason!==BW_HINT_RELEASED)
      $fatal(1,"same-T late edge lost complete prior hint cycle/hit");
    $display("TB_PASS preflight_hint_late_clock mode=%0d",mode);$finish;
  end
endmodule
program settle_hint_renba_driver;
  timeunit 1fs; timeprecision 1fs;
  initial begin
    @(posedge tb_settle_hint_renba.ready);
    if(tb_settle_hint_renba.mode==1)begin
      tb_settle_hint_renba.observed_raw_late_edge=1;
      tb_settle_hint_renba.clk<=1'b1;
    end
  end
endprogram
