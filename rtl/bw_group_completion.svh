  // Group receipts are independent of the collector queues. Native actual
  // clock edges establish obligations even when capture or publication fails.
  class bw_group_batch;
    bw_u64_t expected=0,captured=0,held=0,published=0,accepted=0,acked=0;
    bw_u64_t reset_expected=0,reset_captured=0;
    bw_u64_t ticks=0,input_generation=0,closed_generation=0,grant=0;
    bit cancelled=0;
  endclass
  bw_group_batch group_batches[string];
  function automatic void cancel_all_group_completion();
    foreach(group_batches[id])group_batches[id].cancelled=1;
  endfunction
  function automatic void register_group_completion(string id);
    if(!group_batches.exists(id))group_batches[id]=new;
  endfunction
  function automatic void group_work_requested(string id,bw_u64_t grant);
    if(!monitor_ready || !group_batches.exists(id) || scope_failed(BW_GROUP,id))return;
    if(group_batches[id].input_generation==BW_U64_MAX)begin runtime_scope_error(BW_GROUP,id,"INTEGER_OVERFLOW","group input generation exhausted");return;end
    group_batches[id].input_generation++;group_batches[id].grant=grant;
  endfunction
  function automatic void expect_group_edge(string id,bw_u64_t ticks);
    bw_group_batch batch;
    if(!monitor_ready || ticks<=measurement_start_ticks || scope_failed(BW_GROUP,id))return;
    batch=group_batches[id];
    if(batch.expected!=0 && ticks<=batch.ticks)begin runtime_scope_error(BW_GROUP,id,"GROUP_CLOCK","actual group edges must strictly increase");return;end
    if(batch.expected==BW_U64_MAX)begin runtime_scope_error(BW_GROUP,id,"INTEGER_OVERFLOW","group edge ledger exhausted");return;end
    batch.expected++;batch.ticks=ticks;
    group_work_requested(id,request_slot_settlement(id));
  endfunction
  function automatic void group_reset_expected(string id);
    if(!group_batches.exists(id) || scope_failed(BW_GROUP,id))return;
    if(group_batches[id].reset_expected==BW_U64_MAX)begin runtime_scope_error(BW_GROUP,id,"INTEGER_OVERFLOW","group reset ledger exhausted");return;end
    group_batches[id].reset_expected++;
  endfunction
  function automatic void group_reset_captured(string id);
    if(!group_batches.exists(id) || scope_failed(BW_GROUP,id))return;
    if(group_batches[id].reset_captured==BW_U64_MAX)begin runtime_scope_error(BW_GROUP,id,"INTEGER_OVERFLOW","group reset capture ledger exhausted");return;end
    group_batches[id].reset_captured++;
  endfunction
  function automatic void group_core_receipt(string id,bw_u64_t seq);
    if(scope_failed(BW_GROUP,id))return;
    group_batches[id].accepted=seq;
`ifdef BW_MON_TEST_FAULTS
    if(take_group_fault(id,"notice"))return;
`endif
    group_work_requested(id,request_slot_settlement(id));
  endfunction
  function automatic bit group_batch_complete(string id);
    if(!group_batches.exists(id) || scope_failed(BW_GROUP,id) || group_batches[id].cancelled)return 0;
    return group_batches[id].input_generation==group_batches[id].closed_generation;
  endfunction
  function automatic bit group_producers_pending(int handle);
    bw_source_state source;
    foreach(registered_groups[handle].members[m])begin
      source=registered_sources[registered_groups[handle].members[m]];
      if(source_failed(source))continue;
      if(source.kind==BW_POINT && point_batches.exists(source.id) && !point_batch_complete(source.id))return 1;
      if(source.kind==BW_GROUP && group_batches.exists(source.id) && !group_batch_complete(source.id))return 1;
    end
    return 0;
  endfunction
  function automatic void close_group_batch(string id);
    bw_group_batch batch;
    string stage;
    if(scope_failed(BW_GROUP,id))return;
    batch=group_batches[id];stage="";
    if(batch.captured!=batch.expected)stage="CAPTURE";
    else if(batch.held!=batch.expected)stage="HELD";
    else if(batch.published!=batch.expected)stage="PUBLICATION";
    else if(batch.accepted!=batch.expected)stage="CORE_RECEIPT";
    else if(batch.acked!=batch.expected)stage="INPUT_ACK";
    if(stage!="")begin
      runtime_scope_error(BW_GROUP,id,"GROUP_COMPLETION",$sformatf("stage=%s original_ticks=%0d edge=%0d captured=%0d held=%0d published=%0d accepted=%0d acked=%0d",stage,batch.ticks,batch.expected,batch.captured,batch.held,batch.published,batch.accepted,batch.acked));return;
    end
    batch.closed_generation=batch.input_generation;
  endfunction
