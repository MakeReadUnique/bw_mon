  // One shared end-of-slot callback settles all earlier Active/NBA/Reactive/
  // ReNBA work. Internal publication cascades can request another generation
  // at the same physical tick; no delay or fixed number of delta rounds exists.
  bw_u64_t slot_settlement_generation=0;
  bit slot_settlement_pending=0;
  import "DPI-C" context function int bw_native_request_slot_settlement();
  export "DPI-C" function bw_slot_settlement_arrived;
  // A common export prototype keeps bare-package simulations linkable. A
  // callback must select the owning module's implementation with its svScope.
  export "DPI-C" function bw_native_reset_seen;
  function void bw_native_reset_seen(input bit prepare,input logic previous,input logic current);
    core_error("RESET_OBSERVER_SCOPE","scheduler","native reset callback selected package scope instead of its owner");
  endfunction
  export "DPI-C" function bw_native_point_edge;
  export "DPI-C" function bw_native_point_audit;
  function void bw_native_point_edge();
    core_error("CLOCK_OBSERVER_SCOPE","scheduler","clock observer selected package instead of point owner");
  endfunction
  function int bw_native_point_audit();
    core_error("CLOCK_OBSERVER_SCOPE","scheduler","point audit selected package instead of point owner");return 0;
  endfunction
`ifdef BW_MON_TEST_FAULTS
  import "DPI-C" function void bw_native_fail_reset_allocation();
  import "DPI-C" function void bw_native_fail_slot_registration();
`endif
  function void bw_native_scheduler_failed();
    runtime_shared_error("SLOT_SCHEDULER","scheduler","cannot rearm the writable completion audit");
  endfunction
  export "DPI-C" function bw_native_scheduler_failed;

  function void bw_slot_settlement_arrived();
    slot_settlement_pending=0;
    if(monitoring_shared_disabled || core_failure_seen)return;
    if(slot_settlement_generation==BW_U64_MAX)begin
      runtime_shared_error("INTEGER_OVERFLOW","scheduler","slot generation exhausted");return;
    end
    slot_settlement_generation++;
  endfunction

  function automatic bw_u64_t request_slot_settlement(string id);
    bw_u64_t required;
    if(monitoring_shared_disabled || core_failure_seen)return slot_settlement_generation;
    if(slot_settlement_generation==BW_U64_MAX)begin
      runtime_shared_error("INTEGER_OVERFLOW","scheduler","slot generation exhausted");return slot_settlement_generation;
    end
    required=slot_settlement_generation+1;
    slot_settlement_pending=1;
    // Keep this wrapper in package scope: the native callback must return to
    // this package's exported function, independent of the requesting module.
    if(!bw_native_request_slot_settlement())
      core_error("SLOT_SCHEDULER",id,"cannot register the writable end-of-slot callback; check VCS VPI/debug compile options");
    return required;
  endfunction
