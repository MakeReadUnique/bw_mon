  // Exact value runs retain individual event positions without time buckets.
  task automatic append_event_history(bw_record_t incoming);
    event_run_t run;
    bw_u64_t delta_ticks,delta_edges;
    if(history.size()!=0)begin
      run=history[$];
      if(run.byte_inc==incoming.byte_inc && run.event_inc==incoming.event_inc &&
         run.bytes_complete==incoming.bytes_complete && run.events_complete==incoming.events_complete &&
         run.has_reset==(incoming.reset_points!=0))begin
        delta_ticks=checked_sub(incoming.timestamp_ticks,run.last_ticks,scope_id);
        delta_edges=checked_sub(incoming.edge_index,run.last_edge,scope_id);
        if(core_failure_seen)return;
        if(run.count==1 || (delta_ticks==run.step_ticks && delta_edges==run.step_edges))begin
          if(run.count==1)begin run.step_ticks=delta_ticks;run.step_edges=delta_edges;end
          run.count=checked_add(run.count,1,{scope_id," history count"});
          if(core_failure_seen)return;
          run.last_ticks=incoming.timestamp_ticks;run.last_edge=incoming.edge_index;
          history[$]=run;return;
        end
      end
    end
    run='0;run.first_ticks=incoming.timestamp_ticks;run.first_edge=incoming.edge_index;
    run.last_ticks=incoming.timestamp_ticks;run.last_edge=incoming.edge_index;run.count=1;
    run.byte_inc=incoming.byte_inc;run.event_inc=incoming.event_inc;
    run.bytes_complete=incoming.bytes_complete;run.events_complete=incoming.events_complete;
    run.has_reset=(incoming.reset_points!=0);
    check_queue_growth(history.size(),{scope_id," event history"});
    if(core_failure_seen)return;
    history.push_back(run);
  endtask

  function automatic bw_u64_t count_before(bw_u64_t first,bw_u64_t step,bw_u64_t count,bw_u64_t left);
    bw_u64_t delta,n;
    if(left<=first)return 0;
    if(count==1)return 1;
    if(step==0 || count==0)begin
      core_error("HISTORY_STATE",scope_id,$sformatf("first=%0d step=%0d count=%0d left=%0d",first,step,count,left));
      return 0;
    end
    delta=checked_sub(left,first,scope_id);n=delta/step;
    if(delta%step!=0)n=checked_add(n,1,scope_id);
    return n<count ? n : count;
  endfunction

  task automatic expire_event_history(bw_u64_t left_ticks,bw_u64_t left_cycle);
    event_run_t run,discarded;
    bw_u64_t n,next_bytes,next_events,next_unknown_bytes,next_unknown_events,next_resets;
    while(history.size()!=0)begin
      run=history[0];
      n=(WINDOW_BASIS==BW_NS) ? count_before(run.first_ticks,run.step_ticks,run.count,left_ticks) :
                              count_before(run.first_edge,run.step_edges,run.count,left_cycle);
      if(core_failure_seen || n==0)return;
      next_bytes=checked_sub(retained_bytes,checked_mul(n,run.byte_inc,scope_id),scope_id);
      next_events=checked_sub(retained_events,checked_mul(n,run.event_inc,scope_id),scope_id);
      next_unknown_bytes=run.bytes_complete ? unknown_bytes : checked_sub(unknown_bytes,n,scope_id);
      next_unknown_events=run.events_complete ? unknown_events : checked_sub(unknown_events,n,scope_id);
      next_resets=run.has_reset ? checked_sub(reset_entries,n,scope_id) : reset_entries;
      if(core_failure_seen)return;
      retained_bytes=next_bytes;retained_events=next_events;
      unknown_bytes=next_unknown_bytes;unknown_events=next_unknown_events;reset_entries=next_resets;
      if(n==run.count)discarded=history.pop_front();
      else begin
        run.first_ticks=checked_add(run.first_ticks,checked_mul(n,run.step_ticks,scope_id),scope_id);
        run.first_edge=checked_add(run.first_edge,checked_mul(n,run.step_edges,scope_id),scope_id);
        run.count=checked_sub(run.count,n,scope_id);
        if(core_failure_seen)return;
        history[0]=run;return;
      end
    end
  endtask

  task automatic append_clock_boundary(bw_u64_t at_ticks,bw_u64_t at_edge);
    clock_run_t run;
    bw_u64_t delta_ticks;
    if(clock_runs.size()!=0)begin
      run=clock_runs[$];delta_ticks=checked_sub(at_ticks,run.last_ticks,scope_id);
      if(core_failure_seen)return;
      if(run.count==1 || delta_ticks==run.step_ticks)begin
        if(run.count==1)run.step_ticks=delta_ticks;
        run.count=checked_add(run.count,1,{scope_id," clock count"});
        if(core_failure_seen)return;
        run.last_ticks=at_ticks;clock_runs[$]=run;return;
      end
    end
    run='0;run.first_ticks=at_ticks;run.last_ticks=at_ticks;run.first_edge=at_edge;run.count=1;
    check_queue_growth(clock_runs.size(),{scope_id," clock history"});
    if(core_failure_seen)return;
    clock_runs.push_back(run);
  endtask

  task automatic expire_clock_boundaries(bw_u64_t left_cycle);
    clock_run_t run,discarded;
    bw_u64_t n;
    while(clock_runs.size()!=0 && clock_runs[0].first_edge<left_cycle)begin
      run=clock_runs[0];n=checked_sub(left_cycle,run.first_edge,scope_id);
      if(n>=run.count)discarded=clock_runs.pop_front();
      else begin
        run.first_ticks=checked_add(run.first_ticks,checked_mul(n,run.step_ticks,scope_id),scope_id);
        run.first_edge=checked_add(run.first_edge,n,scope_id);run.count=checked_sub(run.count,n,scope_id);
        if(core_failure_seen)return;
        clock_runs[0]=run;return;
      end
    end
  endtask

  function automatic bw_u64_t left_clock_tick();
    if(clock_runs.size()==0)begin
      core_error("HISTORY_STATE",scope_id,"actual left clock boundary is absent");return 0;
    end
    return clock_runs[0].first_ticks;
  endfunction
