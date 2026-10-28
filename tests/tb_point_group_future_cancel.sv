module tb_point_group_future_cancel;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_u64_t observed_hint_deadline=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("p"),.PROTOCOL(BW_VALID_READY),.WINDOW_WIDTH(100),.FIXED_BYTES(8),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(100)) p
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.ready(1'b0));
  bw_point_mon #(.POINT_ID("q"),.WINDOW_WIDTH(100),.FIXED_BYTES(16)) q
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("g"),.WINDOW_WIDTH(100)) g(.clk(clk),.reset_n(1'b1));
  import "DPI-C" context function int bw_test_observe_group_completion();
  function void bw_test_group_completion_observed();
    if($time!=750001 || !scope_disabled(BW_POINT,"p") || !scope_disabled(BW_GROUP,"g") || scope_disabled(BW_POINT,"q") || q.total_bytes!=32)
      $fatal(1,"future cancellation trust/input differs at original time");
    if(p.core.timer_worker_running || !p.core.timer_worker_cancelled || g.core.timer_worker_running || !g.core.timer_worker_cancelled ||
       p.hints.backpressure_hint.duration.timer_worker_running || !p.hints.backpressure_hint.duration.timer_worker_cancelled ||
       !p.core.scheduler_cancelled || !p.recorder.scheduler_cancelled || !p.hints.backpressure_hint.duration.scheduler_cancelled || !g.collector_cancelled)
      $fatal(1,"actual future core/hint timers or workers waited past cancellation");
    if(p.core.timer_requests!=0 || p.core.timer_receipts!=0 || g.core.timer_requests!=0 ||
       p.hints.backpressure_hint.duration.timer_requests!=0 || p.hints.backpressure_hint.duration.timer_receipts!=0)
      $fatal(1,"cancellation fabricated future timer processing receipts");
    if(q.runtime_cancelled || q.core.runtime_cancelled || !q.core.timer_worker_running || q.core.timer_worker_cancelled)
      $fatal(1,"scoped failure cancelled healthy future timer");
    if(observed_hint_deadline<= $time || p.core.next_update_ticks<=$time || g.core.next_update_ticks<=$time)$fatal(1,"claimed future timer was already due");
    $display("TB_PASS point_group_future_cancel original_ticks=%0d future_core=%0d future_hint=%0d actual_exit=1 fake_receipts=0 healthy_bytes=32",$time,p.core.next_update_ticks,observed_hint_deadline);$finish;
  endfunction
  export "DPI-C" function bw_test_group_completion_observed;
  initial begin
    add_point_member("g","p");wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    if(!p.core.timer_worker_running || !g.core.timer_worker_running || !p.hints.backpressure_hint.duration.timer_worker_running || !p.hints.backpressure_hint.duration.result.active)
      $fatal(1,"future timer cancellation preconditions not reached");
    // Initial known ns backpressure starts at commonT, before any clock.
    if(p.hints.backpressure_hint.duration.result.start_ticks!=measurement_start_ticks ||
       p.hints.backpressure_hint.duration.threshold_ticks!=100000000 || p.core.next_update_ticks!=measurement_start_ticks+100000000 ||
       g.core.next_update_ticks!=measurement_start_ticks+100000000)$fatal(1,"independent future timer preconditions differ");
    observed_hint_deadline=p.hints.backpressure_hint.duration.result.start_ticks+p.hints.backpressure_hint.duration.threshold_ticks;
    if(observed_hint_deadline!=measurement_start_ticks+100000000)$fatal(1,"actual hint deadline differs from T+100ns");
    inject_point_fault("p","capture");#499999;clk=1;
    if(!bw_test_observe_group_completion())$fatal(1,"cannot register future cancel nativeRO verifier");
  end
endmodule
