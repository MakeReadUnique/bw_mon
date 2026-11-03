// Ticket 56 slice 2: target-qualified completion state. A request registered
// before its endpoint binds the ingress generation at registration; stale
// idle (0==0) and already-closed generations cannot satisfy it. The T+40us
// endpoint settles at the original physical tick; +1fs is the counterexample.
module tb_target_query;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  string mode;
  int target_handle;
  bw_u64_t target_tick;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("target.point"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .FIXED_BYTES(8)) p(.clk(clk),.reset_n(1'b1),.valid(valid));
  import "DPI-C" context function int bw_test_observe_target_query();
  function void bw_test_target_query_observed();
    if($time!=target_tick)
      $fatal(1,"target endpoint must be observed at the original tick %0d, got %0d",
        target_tick,$time);
    if(target_completion_state(target_handle)!=BW_TARGET_NORMAL)
      $fatal(1,"target completion must be NORMAL at the same original tick");
    if(target_completion_ticks(target_handle)!=target_tick)
      $fatal(1,"target settled at %0d, must stay the original tick %0d",
        target_completion_ticks(target_handle),target_tick);
    if(p.total_bytes!=320)
      $fatal(1,"independent byte count at the endpoint is %0d, expected 320",p.total_bytes);
    $display("TB_PASS target_query %s time=%0d bytes=320",mode,$time);$finish;
  endfunction
  export "DPI-C" function bw_test_target_query_observed;
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="stale";
    wait(monitor_ready);
    target_tick=measurement_start_ticks+40000000;
    if(mode=="stale") begin
      // No sampling edge after ready: the current-generation equality
      // (0==0) must not satisfy a registered target request.
      target_handle=request_scope_completion(BW_POINT,"target.point",target_tick);
      if(target_completion_state(target_handle)!=BW_TARGET_PENDING)
        $fatal(1,"an idle scope must stay PENDING, got %0d",target_completion_state(target_handle));
      #1000000;
      if(target_completion_state(target_handle)!=BW_TARGET_PENDING)
        $fatal(1,"old idle snapshot must never satisfy a target request");
      $display("TB_PASS target_query stale");$finish;
    end
    if(mode=="late1fs") begin
      // Counterexample twin: one tick after the endpoint the settled state
      // must still name the original tick, never a deferred settlement.
      #1000000;clk=1;#1;clk=0;
      repeat(38) begin #999999;clk=1;#1;clk=0;end
      wait(point_batch_complete("target.point"));
      target_handle=request_scope_completion(BW_POINT,"target.point",target_tick);
      #999999;clk=1;#1;clk=0;
      if($time!=target_tick+1)
        $fatal(1,"late twin must query one tick past the endpoint, got %0d",$time);
      if(target_completion_state(target_handle)!=BW_TARGET_NORMAL ||
         target_completion_ticks(target_handle)!=target_tick)
        $fatal(1,"settlement must have happened at %0d, not deferred; state=%0d settled=%0d",
          target_tick,target_completion_state(target_handle),target_completion_ticks(target_handle));
      $display("TB_PASS target_query late1fs settled=%0d",target_completion_ticks(target_handle));$finish;
    end
    // budget mode: 39 edges, request, then trigger the 40th edge at
    // T+40us and observe completion in the same-tick native read-only cut.
    #1000000;clk=1;#1;clk=0;
    repeat(38) begin #999999;clk=1;#1;clk=0;end
    wait(point_batch_complete("target.point"));
    target_handle=request_scope_completion(BW_POINT,"target.point",target_tick);
    #999999;clk=1;
    if(!bw_test_observe_target_query())
      $fatal(1,"cannot register original-time target observer");
  end
endmodule
