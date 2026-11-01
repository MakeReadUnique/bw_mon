  // One shared end-of-slot callback settles all earlier Active/NBA/Reactive/
  // ReNBA work. Internal publication cascades can request another generation
  // at the same physical tick; no delay or fixed number of delta rounds exists.
  bw_u64_t slot_settlement_generation=0;
  bit slot_settlement_pending=0;
  import "DPI-C" context function int bw_native_request_slot_settlement();
  // Audit-relevant receipts (continuations, publications, grants, batch
  // ledgers) can change without any raw clock/reset transition of the owning
  // scope. Owners register their raw-clock observer once; the completion
  // funnels report such activity so the native audit round visits the scope.
  import "DPI-C" function void bw_native_mark_settlement_watch(input chandle handle);
  import "DPI-C" function void bw_native_note_generation(input longint unsigned generation);
  import "DPI-C" function void bw_native_cancel_slot_settlement();
  import "DPI-C" context function int bw_native_settlement_activity_request(input chandle handle,
    input longint unsigned grant);
  chandle point_settlement_watches[string],group_settlement_watches[string];
  function automatic chandle settlement_watch_for_scope(bw_scope_t kind,string id);
    if(kind==BW_POINT && point_settlement_watches.exists(id))return point_settlement_watches[id];
    if(kind==BW_GROUP && group_settlement_watches.exists(id))return group_settlement_watches[id];
    return null;
  endfunction
  function automatic void register_settlement_watch(bw_scope_t kind,string id,chandle handle);
    if(kind==BW_POINT)point_settlement_watches[id]=handle;
    else if(kind==BW_GROUP)group_settlement_watches[id]=handle;
    // Publish the handle on the registry records too so the hot transport
    // paths (notifications, grants) need no keyed owner lookup.
    if(kind==BW_POINT && point_by_id.exists(id))
      registered_sources[registered_points[point_by_id[id]].transport_source].settlement_watch=handle;
    if(kind==BW_GROUP && group_by_id.exists(id))begin
      registered_groups[group_by_id[id]].settlement_watch=handle;
      registered_sources[registered_groups[group_by_id[id]].source_handle].settlement_watch=handle;
    end
  endfunction
  function automatic void note_settlement_activity(bw_scope_t kind,string id);
    if(kind==BW_POINT)begin
      if(point_settlement_watches.exists(id))bw_native_mark_settlement_watch(point_settlement_watches[id]);
    end
    else if(kind==BW_GROUP)begin
      if(group_settlement_watches.exists(id))bw_native_mark_settlement_watch(group_settlement_watches[id]);
    end
  endfunction
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
    bw_native_note_generation(slot_settlement_generation);
  endfunction

  function automatic bw_u64_t request_slot_settlement(string id,chandle watch=null,bw_scope_t kind=BW_POINT);
    bw_u64_t required;
    if(monitoring_shared_disabled || core_failure_seen)return slot_settlement_generation;
    if(slot_settlement_generation==BW_U64_MAX)begin
      runtime_shared_error("INTEGER_OVERFLOW","scheduler","slot generation exhausted");return slot_settlement_generation;
    end
    required=slot_settlement_generation+1;
    slot_settlement_pending=1;
    if(watch==null)watch=settlement_watch_for_scope(kind,id);
    // The native scheduler skips a watcher dispatch while its latest grant
    // still awaits this generation; the combined native call reports the
    // grant, marks the requesting watcher and registers the end-of-slot
    // callback in one crossing.
    if(watch!=null)begin
      if(!bw_native_settlement_activity_request(watch,required))
        core_error("SLOT_SCHEDULER",id,"cannot register the writable end-of-slot callback; check VCS VPI/debug compile options");
    end
    else begin
      // Keep this wrapper in package scope: the native callback must return to
      // this package's exported function, independent of the requesting module.
      if(!bw_native_request_slot_settlement())
        core_error("SLOT_SCHEDULER",id,"cannot register the writable end-of-slot callback; check VCS VPI/debug compile options");
    end
    return required;
  endfunction
