  // Cumulative receipts survive dequeue, lost wakeups, reset and shutdown.
  // Only the native raw-clock observer creates expected edges.
  class bw_point_batch;
    bw_u64_t expected=0,captured=0,inflight=0,published=0,accepted=0;
    bw_u64_t ticks=0,input_generation=0,closed_generation=0,grant=0;
    bit cancelled=0;
  endclass
  bw_point_batch point_batches[string];
  function automatic void register_point_completion(string id);
    if(!point_batches.exists(id))point_batches[id]=new;
  endfunction
  function automatic void cancel_point_completion(string id);
    if(point_batches.exists(id))point_batches[id].cancelled=1;
  endfunction
  function automatic void point_work_requested(string id,bw_u64_t grant);
    if(!monitor_ready || !point_batches.exists(id) || scope_failed(BW_POINT,id))return;
    if(point_batches[id].input_generation==BW_U64_MAX)begin
      runtime_scope_error(BW_POINT,id,"INTEGER_OVERFLOW","input generation exhausted");return;
    end
    point_batches[id].input_generation++;
    point_batches[id].grant=grant;
  endfunction
  function automatic void expect_point_edge(string id,bw_u64_t ticks);
    bw_point_batch batch;
    if(!monitor_ready || ticks<=measurement_start_ticks || scope_failed(BW_POINT,id))return;
    batch=point_batches[id];
    if(batch.expected!=0 && ticks<=batch.ticks)begin
      runtime_scope_error(BW_POINT,id,"EDGE_TIME","actual sampling edges must have distinct increasing timestamps");return;
    end
    if(batch.expected==BW_U64_MAX || batch.input_generation==BW_U64_MAX)begin
      runtime_scope_error(BW_POINT,id,"INTEGER_OVERFLOW","expected-edge ledger exhausted");return;
    end
    batch.expected++;batch.input_generation++;batch.ticks=ticks;
    batch.grant=request_slot_settlement(id);
  endfunction
  function automatic void point_capture_receipt(string id,bw_u64_t seq);
    if(!point_batches.exists(id) || scope_failed(BW_POINT,id))return;
    if(seq!=point_batches[id].captured+1)begin
      runtime_scope_error(BW_POINT,id,"CAPTURE_SEQUENCE","duplicate or out-of-order capture receipt");return;
    end
    point_batches[id].captured=seq;
  endfunction
  function automatic void point_inflight_receipt(string id,bw_u64_t seq);
    if(!point_batches.exists(id) || scope_failed(BW_POINT,id))return;
    point_batches[id].inflight=seq;
  endfunction
  function automatic void point_publication_receipt(string id,bw_u64_t seq);
    if(!point_batches.exists(id) || scope_failed(BW_POINT,id))return;
    point_batches[id].published=seq;
  endfunction
  function automatic void point_core_receipt(string id,bw_u64_t seq);
    if(!point_batches.exists(id) || scope_failed(BW_POINT,id))return;
    point_batches[id].accepted=seq;
    // A wakeup is expendable. The next coordinator audit reads this durable
    // receipt even when this advisory request is deliberately lost.
`ifdef BW_MON_TEST_FAULTS
    if(take_point_fault(id,"notice"))return;
`endif
    void'(request_slot_settlement(id));
  endfunction
  function automatic void close_point_batch(string id);
    bw_point_batch batch;
    string stage;
    if(!point_batches.exists(id) || scope_failed(BW_POINT,id))return;
    batch=point_batches[id];stage="";
    if(batch.captured!=batch.expected)stage="CAPTURE";
    else if(batch.inflight!=batch.expected)stage="INFLIGHT";
    else if(batch.published!=batch.expected)stage="PUBLICATION";
    else if(batch.accepted!=batch.expected)stage="CORE_RECEIPT";
    if(stage!="")begin
      runtime_scope_error(BW_POINT,id,"POINT_COMPLETION",$sformatf("stage=%s original_ticks=%0d edge=%0d captured=%0d inflight=%0d published=%0d accepted=%0d input_generation=%0d",stage,batch.ticks,batch.expected,batch.captured,batch.inflight,batch.published,batch.accepted,batch.input_generation));return;
    end
    batch.closed_generation=batch.input_generation;
  endfunction
  function automatic bit point_batch_complete(string id);
    if(!point_batches.exists(id))return 0;
    return point_batches[id].closed_generation==point_batches[id].input_generation;
  endfunction
  typedef enum {BW_SCOPE_RUNNING,BW_SCOPE_NORMAL,BW_SCOPE_DISABLED,BW_SCOPE_INTERRUPTED,BW_SCOPE_UNOBSERVED} bw_scope_terminal_t;
  bw_scope_terminal_t scope_terminals[string];
  function automatic bw_scope_terminal_t scope_terminal_state(bw_scope_t kind,string id);
    if(scope_disabled(kind,id))return BW_SCOPE_DISABLED;
    if(!scope_terminals.exists(scope_key(kind,id)))return BW_SCOPE_RUNNING;
    return scope_terminals[scope_key(kind,id)];
  endfunction
  function automatic void note_point_terminal(string id,bit actions_complete);
    string state,key;
    bw_scope_terminal_t terminal;
    key=scope_key(BW_POINT,id);
    if(scope_terminals.exists(key))return;
    if(scope_disabled(BW_POINT,id))begin terminal=BW_SCOPE_DISABLED;state="DISABLED";end
    else if(!actions_complete || !point_batch_complete(id))begin terminal=BW_SCOPE_INTERRUPTED;state="INTERRUPTED";end
    else if(point_batches[id].expected==0)begin terminal=BW_SCOPE_UNOBSERVED;state="UNOBSERVED";end
    else begin terminal=BW_SCOPE_NORMAL;state="NORMAL";end
    scope_terminals[key]=terminal;
    $display("BW_POINT_TERMINAL scope=%s state=%s expected=%0d captured=%0d inflight=%0d published=%0d accepted=%0d input_generation=%0d closed_generation=%0d time_ticks=%0d",id,state,point_batches[id].expected,point_batches[id].captured,point_batches[id].inflight,point_batches[id].published,point_batches[id].accepted,point_batches[id].input_generation,point_batches[id].closed_generation,$time);
  endfunction
