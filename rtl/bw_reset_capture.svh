  // Private per-owner capture. Native code transports four-state input levels;
  // timestamps, ordered payload storage and all state transitions stay in SV.
  typedef struct packed {bw_u64_t ticks;logic level;} captured_reset_t;
  captured_reset_t captured_resets[$];
  chandle reset_capture_handle=null;
  bit reset_capture_initialized=0;
  logic reset_capture_last;
  import "DPI-C" context function chandle bw_native_watch_reset(input string scope_path,input string signal_name);
  import "DPI-C" context function void bw_native_reset_snapshot(input chandle handle);
  import "DPI-C" function int bw_native_reset_watch_error();
  import "DPI-C" function longint unsigned bw_native_reset_watch_count();

  function automatic void append_captured_reset(logic value,bw_u64_t ticks);
    captured_reset_t action;
    if(reset_capture_initialized && reset_capture_last===value)return;
    // An initial snapshot is preparation even for an isolated component whose
    // caller does not participate in the public ready handshake.
    check_storage_growth(captured_resets.size(),scope_id,"scheduler.reset_capture",ticks,0,0,!reset_capture_initialized);
    if(scope_failed(bw_scope_t'(scope_kind),scope_id))return;
    action.ticks=ticks;action.level=value;captured_resets.push_back(action);
    reset_capture_initialized=1;reset_capture_last=value;
  endfunction

  function void bw_native_reset_seen(input bit prepare,input logic previous,input logic current);
    captured_reset_t action;
    // The capture gate is the seal, not the ready publication: internal
    // preparation (including the initial reset snapshot) completes inside the
    // sealed slot before ready is published once.
    if(external_reset_capture || !configuration_sealed || scope_failed(bw_scope_t'(scope_kind),scope_id))return;
    if(!prepare)begin
      check_monitor_time($time,scope_id);
      if(scope_failed(bw_scope_t'(scope_kind),scope_id))return;
      if(!reset_capture_initialized)append_captured_reset(previous,$time);
      append_captured_reset(current,$time);
      if(!scope_failed(bw_scope_t'(scope_kind),scope_id))void'(request_slot_settlement(scope_id));
    end else begin
      if(!reset_observer_ready)begin
        core_error("SLOT_SCHEDULER",scope_id,"reset capture owner was not initialized before settlement");return;
      end
      while(captured_resets.size()!=0 && !scope_failed(bw_scope_t'(scope_kind),scope_id))begin
        action=captured_resets.pop_front();
        apply_captured_reset(action.level,action.ticks);
      end
    end
  endfunction

  export "DPI-C" function bw_native_reset_seen;
  function automatic void initialize_reset_capture(string scope_path,string signal_name);
    bw_u64_t observer_count;
    if(external_reset_capture)return;
    observer_count=bw_native_reset_watch_count();
    if(observer_count>=64'd2147483647)begin
      core_error("STORAGE_RANGE",scope_id,$sformatf("resource=scheduler.reset_observer entries=%0d cannot be indexed",observer_count));return;
    end
    check_storage_growth(int'(observer_count),scope_id,"scheduler.reset_observer",$time);
    if(scope_failed(bw_scope_t'(scope_kind),scope_id))return;
    reset_capture_handle=bw_native_watch_reset(scope_path,signal_name);
    if(reset_capture_handle==null)begin
      if(bw_native_reset_watch_error()==1)
        core_error("STORAGE_FAILURE",scope_id,$sformatf("resource=scheduler.reset_observer entries=%0d requested=1 native allocation failed",observer_count));
      else core_error("SLOT_SCHEDULER",scope_id,"cannot observe the raw reset input; check VCS VPI/debug compile options");
    end
  endfunction
