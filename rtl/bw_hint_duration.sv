// Private state machine reused by the two independent public hint kinds.
module bw_hint_duration #(
  parameter string HINT_NAME = "hint",
  parameter logic [1:0] SUPPORTED = 0,
  parameter logic [1:0] ENABLED = 0,
  parameter logic [1:0] BASIS = 2'bxx,
  parameter logic [63:0] THRESHOLD = 64'bx
) (
  input string scope_id,
  input logic clk,
  input logic reset_n,
  input logic raw_condition,
  output bw_mon_pkg::bw_hint_result_t result
);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  localparam bw_scope_t scope_kind=BW_POINT;
  `include "bw_scope_runtime.svh"
  typedef struct packed {bw_u64_t at_ticks;logic condition_value;logic reset_value;} status_action_t;
  typedef struct packed {bw_u64_t at_ticks;bw_u64_t index;} edge_action_t;
  typedef struct packed {bw_u64_t at_ticks;bw_u64_t generation;} timer_action_t;
  status_action_t pending_status[$];
  edge_action_t pending_edges[$];
  timer_action_t pending_timers[$];
  bw_u64_t requested_actions=0,consumed_actions=0;
  bw_u64_t settlement_required=0;
  bw_u64_t timer_requests=0,timer_receipts=0,timer_schedule_seq=0;
  bw_u64_t edge_sequence=0,last_edge_ticks=0,last_edge_index=0,threshold_ticks=0;
  bit configured=0,reset_held=0,edge_seen=0;
  bit external_reset_capture=0,assertion_seen=0;
  bit reset_observer_ready=0;
  bw_u64_t last_assert_ticks=0;
  function void use_external_reset_capture();external_reset_capture=1;endfunction
  function void apply_captured_reset(logic value,bw_u64_t ticks);enqueue_status(value,ticks);
    if(runtime_failed())return;endfunction
  `include "bw_reset_capture.svh"

  function automatic void begin_action(int current_size,string queue_kind);
    check_monitor_time($time,{scope_id," ",HINT_NAME});
    if(runtime_failed())return;
    check_storage_growth(current_size,scope_id,{"hint.",HINT_NAME,".",queue_kind},$time,last_edge_index,0);
    if(runtime_failed())return;
  endfunction

  function automatic void touch(bw_u64_t at_ticks);
    if(runtime_failed()) return;
    result.update_ticks=at_ticks;
    result.result_seq=checked_add(result.result_seq,1,{scope_id," ",HINT_NAME," result"});
    if(runtime_failed())return;
  endfunction
  function automatic void hit_once(bw_u64_t at_ticks);
    if(result.hit || runtime_failed()) return;
    result.hit=1;
    result.trigger_ticks=(BASIS==BW_NS) ? checked_add(result.start_ticks,threshold_ticks,scope_id) : at_ticks;
    if(runtime_failed())return;
    result.hit_count=checked_add(result.hit_count,1,{scope_id," ",HINT_NAME," hit count"});
    if(runtime_failed())return;
    timer_schedule_seq=checked_add(timer_schedule_seq,1,scope_id);
    if(runtime_failed())return;
    touch(at_ticks);
    if(runtime_failed())return;
    if(runtime_failed()) return;
    $display("BW_HINT_HIT scope=%s kind=%s epoch=%0d interval_id=%0d result_seq=%0d basis=%s threshold=%0d start_ticks=%0d trigger_ticks=%0d duration_ticks=%0d duration_cycles=%0d",
      scope_id,HINT_NAME,result.interval_epoch,result.interval_id,result.result_seq,
      BASIS==BW_NS ? "ns" : "cycle",THRESHOLD,result.start_ticks,result.trigger_ticks,
      result.duration_ticks,result.duration_cycles);
  endfunction
  function automatic void advance_interval(bw_u64_t at_ticks);
    if(!result.active || runtime_failed()) return;
    if(at_ticks<result.start_ticks)
      core_error("HINT_TIME",scope_id,$sformatf("start_ticks=%0d received_ticks=%0d",result.start_ticks,at_ticks));
    if(runtime_failed())return;
    if(runtime_failed()) return;
    result.observed_through_ticks=at_ticks;
    result.duration_ticks=at_ticks-result.start_ticks;
    if((BASIS==BW_NS && result.duration_ticks>=threshold_ticks) ||
       (BASIS==BW_CYCLE && result.duration_cycles>=THRESHOLD)) hit_once(at_ticks);
    if(runtime_failed())return;
  endfunction
  function automatic void close_interval(bw_u64_t at_ticks,bw_hint_end_t reason);
    if(!result.active || runtime_failed()) return;
    // [start,T) is settled before the condition/reset value at T is applied.
    advance_interval(at_ticks);
    if(runtime_failed())return;
    if(runtime_failed()) return;
    result.active=0;result.end_ticks=at_ticks;result.end_reason=reason;
    result.interval_count=checked_add(result.interval_count,1,scope_id);
    if(runtime_failed())return;
    timer_schedule_seq=checked_add(timer_schedule_seq,1,scope_id);
    if(runtime_failed())return;
    touch(at_ticks);
    if(runtime_failed())return;
    if(runtime_failed()) return;
    $display("BW_HINT_END scope=%s kind=%s epoch=%0d interval_id=%0d result_seq=%0d reason=%s hit=%0d start_ticks=%0d trigger_ticks=%0d end_ticks=%0d duration_ticks=%0d duration_cycles=%0d",
      scope_id,HINT_NAME,result.interval_epoch,result.interval_id,result.result_seq,hint_end_name(reason),
      result.hit,result.start_ticks,result.trigger_ticks,result.end_ticks,result.duration_ticks,result.duration_cycles);
  endfunction
  function automatic void start_interval(bw_u64_t at_ticks);
    if(runtime_failed()) return;
    result.active=1;result.hit=0;result.end_reason=BW_HINT_NOT_ENDED;
    result.interval_id=checked_add(result.interval_id,1,scope_id);
    if(runtime_failed())return;result.interval_epoch=result.epoch;
    result.start_ticks=at_ticks;result.observed_through_ticks=at_ticks;
    result.trigger_ticks=0;result.end_ticks=0;result.duration_ticks=0;result.duration_cycles=0;
    result.cycle_anchor_valid=(BASIS==BW_CYCLE && edge_seen && last_edge_ticks==at_ticks);
    result.start_cycle=result.cycle_anchor_valid ? last_edge_index : 0;
    result.end_cycle=result.start_cycle;
    timer_schedule_seq=checked_add(timer_schedule_seq,1,scope_id);
    if(runtime_failed())return;
    touch(at_ticks);
    if(runtime_failed())return;
  endfunction
  function automatic void process_status(status_action_t action);
    if(runtime_failed()) return;
    advance_interval(action.at_ticks);
    if(runtime_failed())return;
    if(runtime_failed()) return;
    if(action.reset_value===1'b0) begin
      close_interval(action.at_ticks,BW_HINT_RESET);
      if(runtime_failed())return;
      if(!reset_held) result.epoch=checked_add(result.epoch,1,scope_id);
      if(runtime_failed())return;
      assertion_seen=1;last_assert_ticks=action.at_ticks;
      reset_held=1;result.trusted=0;touch(action.at_ticks);
      if(runtime_failed())return;return;
    end
    reset_held=0;
    if(action.reset_value!==1'b1 || $isunknown(action.condition_value)) begin
      close_interval(action.at_ticks,BW_HINT_UNKNOWN);
      if(runtime_failed())return;
      result.trusted=0;touch(action.at_ticks);
      if(runtime_failed())return;return;
    end
    result.trusted=1;
    if(action.condition_value) begin
      if(!result.active) start_interval(action.at_ticks);
      if(runtime_failed())return;
    end else close_interval(action.at_ticks,BW_HINT_RELEASED);
    if(runtime_failed())return;
    touch(action.at_ticks);
    if(runtime_failed())return;
  endfunction
  function automatic void process_edge(edge_action_t action);
    if(runtime_failed()) return;
    if(edge_seen && action.at_ticks<=last_edge_ticks)
      core_error("HINT_CLOCK",scope_id,"sampling edge timestamps must strictly increase");
    if(runtime_failed())return;
    edge_seen=1;last_edge_ticks=action.at_ticks;last_edge_index=action.index;
    if(!result.active || runtime_failed()) return;
    if(BASIS==BW_CYCLE) begin
      if(!result.cycle_anchor_valid) begin
        result.cycle_anchor_valid=1;result.start_cycle=action.index;
      end else result.duration_cycles=checked_add(result.duration_cycles,1,scope_id);
      if(runtime_failed())return;
      result.end_cycle=action.index;
    end
    advance_interval(action.at_ticks);
    if(runtime_failed())return;touch(action.at_ticks);
    if(runtime_failed())return;
  endfunction
  function automatic void enqueue_status(logic reset_value,bw_u64_t at_ticks);
    status_action_t action;
    if(!configured || !configuration_sealed || !SUPPORTED || !ENABLED || runtime_failed()) return;
    begin_action(pending_status.size(),"status");
    if(runtime_failed())return;
    action.at_ticks=at_ticks;action.condition_value=raw_condition;action.reset_value=reset_value;
    pending_status.push_back(action);requested_actions=checked_add(requested_actions,1,scope_id);
    if(runtime_failed())return;
    settlement_required=request_slot_settlement(scope_id);
  endfunction
  function automatic void drain_actions();
    edge_action_t edge_action;
    status_action_t status_action;
    timer_action_t timer_action;
    int status_index;
    while(consumed_actions!=requested_actions && !runtime_failed()) begin
      // Actual edge metadata exists before recorder ReNBA publication. Complete
      // the prior cycle before applying same-time release/unknown/reset changes.
      if(pending_edges.size()!=0) begin edge_action=pending_edges.pop_front();process_edge(edge_action);
        if(runtime_failed())return;end
      else if(pending_status.size()!=0) begin
        status_index=0;
        if(!(assertion_seen && last_assert_ticks==pending_status[0].at_ticks))
          foreach(pending_status[s])
            if(pending_status[s].at_ticks==pending_status[0].at_ticks &&
               pending_status[s].reset_value===1'b0)begin status_index=s;break;end
        repeat(status_index)begin
          status_action=pending_status.pop_front();reset_held=0;
          consumed_actions=checked_add(consumed_actions,1,scope_id);
          if(runtime_failed())return;
        end
        status_action=pending_status.pop_front();process_status(status_action);
        if(runtime_failed())return;
      end
      else begin
        timer_action=pending_timers.pop_front();
        if(timer_action.generation==timer_schedule_seq && result.active) begin
          advance_interval(timer_action.at_ticks);
          if(runtime_failed())return;touch(timer_action.at_ticks);
          if(runtime_failed())return;
        end
        timer_receipts=checked_add(timer_receipts,1,scope_id);
        if(runtime_failed())return;
      end
      if(runtime_failed()) return;
      consumed_actions=checked_add(consumed_actions,1,scope_id);
      if(runtime_failed())return;
    end
  endfunction

  initial begin
    result='0;result.supported=SUPPORTED;result.enabled=ENABLED;
    wait(scope_id.len()!=0);
    validate_hint_config(SUPPORTED,ENABLED,BASIS,THRESHOLD,scope_id,HINT_NAME);
    if(SUPPORTED && ENABLED && BASIS==BW_NS) threshold_ticks=ns_to_ticks(THRESHOLD,scope_id);
    initialize_reset_capture($sformatf("%m"),"reset_n");
    configured=1;enqueue_status(reset_n,$time);
  end
  always @(raw_condition) enqueue_status(reset_n,$time);
  initial begin
    wait(configured && configuration_sealed);
    if(!external_reset_capture)begin
      wait(reset_capture_handle!=null);reset_observer_ready=1;bw_native_reset_snapshot(reset_capture_handle);
    end
  end
  always @(posedge clk) begin : capture_hint_edge
    edge_action_t action;
    if(configured && monitor_ready && $time>measurement_start_ticks && SUPPORTED && ENABLED && !runtime_failed()) begin
      begin_action(pending_edges.size(),"edges");
      if(runtime_failed())disable capture_hint_edge;
      edge_sequence=checked_add(edge_sequence,1,scope_id);
      action.at_ticks=$time;action.index=edge_sequence;
      pending_edges.push_back(action);requested_actions=checked_add(requested_actions,1,scope_id);
      settlement_required=request_slot_settlement(scope_id);
    end
  end
  bw_hint_duration_scheduler scheduler();
  if(SUPPORTED && ENABLED && (BASIS===2'd0)) begin : ns_timer
    initial begin : hint_timer_worker
      bw_u64_t schedule,due_ticks,request;
      timer_action_t action;
      wait(configured && monitor_ready);
      forever begin
        wait((result.active && !result.hit) || runtime_failed());
        if(runtime_failed())disable hint_timer_worker;
        schedule=timer_schedule_seq;due_ticks=checked_add(result.start_ticks,threshold_ticks,scope_id);
        if($time<due_ticks) begin
          fork : wait_for_hint
            begin #(due_ticks-$time);end
            begin wait(timer_schedule_seq!=schedule || runtime_failed());end
          join_any
          disable wait_for_hint;
        end
        if(runtime_failed())disable hint_timer_worker;
        if(timer_schedule_seq==schedule && result.active && !result.hit && $time>=due_ticks) begin
          begin_action(pending_timers.size(),"timers");
          if(runtime_failed())disable hint_timer_worker;
          action.at_ticks=due_ticks;action.generation=schedule;pending_timers.push_back(action);
          timer_requests=checked_add(timer_requests,1,scope_id);request=timer_requests;
          requested_actions=checked_add(requested_actions,1,scope_id);
          settlement_required=request_slot_settlement(scope_id);
          wait(timer_receipts>=request || runtime_failed());
          if(runtime_failed())disable hint_timer_worker;
        end
      end
    end
  end
  final begin
    if(configured && !core_failure_pending() && !scope_disabled(bw_scope_t'(scope_kind),scope_id) &&
        (!point_batches.exists(scope_id) || point_batch_complete(scope_id)) && requested_actions==consumed_actions)begin
      if(!core_failure_pending() && !scope_disabled(bw_scope_t'(scope_kind),scope_id) && result.active) begin
        if(monitor_time_supported($time)) close_interval($time,BW_HINT_TRUNCATED);
        else check_monitor_time($time,{scope_id," ",HINT_NAME," final"});
      end
    end
  end
endmodule

program bw_hint_duration_scheduler;
  timeunit 1fs;timeprecision 1fs;
  initial forever begin
    wait(!bw_mon_pkg::scope_failed(bw_mon_pkg::bw_scope_t'(bw_hint_duration.scope_kind),bw_hint_duration.scope_id) && bw_hint_duration.requested_actions!=bw_hint_duration.consumed_actions);
    wait(bw_mon_pkg::slot_settlement_generation>=bw_hint_duration.settlement_required ||
      bw_mon_pkg::scope_failed(bw_mon_pkg::BW_POINT,bw_hint_duration.scope_id));
    bw_hint_duration.drain_actions();
  end
endprogram
