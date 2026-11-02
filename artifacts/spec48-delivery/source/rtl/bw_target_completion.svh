  // Ticket 56 target-qualified completion. A request is registered BEFORE its
  // endpoint is triggered and binds the actual ingress generation observed at
  // registration time. Satisfaction requires a NEW actual ingress whose full
  // responsibility chain closed after that binding, at its original tick.
  // The historical current-generation equality (initial 0==0) and any
  // already-closed generation therefore can never satisfy a target request.
  typedef enum {BW_TARGET_PENDING,BW_TARGET_NORMAL,BW_TARGET_INTERRUPTED,
    BW_TARGET_CANCELLED} bw_target_state_t;
  class bw_target_request;
    bw_scope_t kind;
    string id;
    bw_u64_t target_ticks;
    // Bound actual sampling-edge count at registration time.
    bw_u64_t binding_generation;
    bw_target_state_t state;
    bw_u64_t settled_ticks;
  endclass
  bw_target_request target_requests[int];

  // A durable close covering a NEW actual ingress settles matching pending
  // requests. Runtime grants alone never move the bound edge count.
  function automatic void settle_target_requests(bw_scope_t kind,string id,
      bw_u64_t closed_edges);
    foreach(target_requests[h])
      if(target_requests[h].state==BW_TARGET_PENDING &&
         target_requests[h].kind==kind && target_requests[h].id==id &&
         closed_edges>target_requests[h].binding_generation)begin
        target_requests[h].state=BW_TARGET_NORMAL;
        target_requests[h].settled_ticks=$time;
      end
  endfunction

  // Reaching a scope terminal while a request is still pending means the
  // endpoint never completed on top of that responsibility: interrupted, or
  // cancelled when the scope itself stopped monitoring.
  function automatic void interrupt_target_requests(bw_scope_t kind,string id,
      bit cancelled);
    foreach(target_requests[h])
      if(target_requests[h].state==BW_TARGET_PENDING &&
         target_requests[h].kind==kind && target_requests[h].id==id)begin
        target_requests[h].state=cancelled ? BW_TARGET_CANCELLED : BW_TARGET_INTERRUPTED;
        target_requests[h].settled_ticks=$time;
      end
  endfunction
