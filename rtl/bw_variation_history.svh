  // Qualification, values and exact publication times remain splittable until
  // ownership is irrevocable. Excluded samples never contribute their value.
  function automatic variation_sample_t first_variation_sample(variation_run_t run);
    return '{ticks:run.ticks,value:run.value,warmup:run.warmup,foreign_activity:run.foreign_activity,
             unknown_observation:run.unknown_observation,bad_denominator:run.bad_denominator};
  endfunction

  task automatic append_variation_history(ref variation_run_t buffer[$],input variation_sample_t sample,input string resource);
    variation_run_t run;
    bw_u64_t delta_ticks;
    bit same_flags,excluded;
    if(buffer.size()!=0)begin
      run=buffer[$];
      same_flags=(run.warmup==sample.warmup && run.foreign_activity==sample.foreign_activity &&
        run.unknown_observation==sample.unknown_observation && run.bad_denominator==sample.bad_denominator);
      excluded=sample.warmup || sample.foreign_activity || sample.unknown_observation || sample.bad_denominator;
      if(same_flags && (excluded || $realtobits(run.value)==$realtobits(sample.value)))begin
        delta_ticks=checked_sub(sample.ticks,run.last_ticks,scope_id);
        if(runtime_failed())return;
        if(run.count==1 || delta_ticks==run.step_ticks)begin
          if(run.count==1)run.step_ticks=delta_ticks;
          run.count=checked_add(run.count,1,{scope_id," pending publication count"});
          if(runtime_failed())return;
          run.last_ticks=sample.ticks;buffer[$]=run;return;
        end
      end
    end
    run='{ticks:sample.ticks,last_ticks:sample.ticks,count:1,step_ticks:0,value:sample.value,
      warmup:sample.warmup,foreign_activity:sample.foreign_activity,
      unknown_observation:sample.unknown_observation,bad_denominator:sample.bad_denominator};
    check_storage_growth(buffer.size(),scope_id,resource,sample.ticks,last_edge_index,last_record_seq);
    if(runtime_failed())return;
    buffer.push_back(run);
  endtask

  task automatic pop_variation_sample(ref variation_run_t buffer[$],output variation_sample_t sample);
    variation_run_t run,discarded;
    if(buffer.size()==0)begin
      core_error("HISTORY_STATE",scope_id,"pending publication is absent");
      if(runtime_failed())return;
      sample='{default:0};return;
    end
    run=buffer[0];sample=first_variation_sample(run);
    if(run.count==1)discarded=buffer.pop_front();
    else begin
      if(run.step_ticks==0 || run.count==0)begin
        core_error("HISTORY_STATE",scope_id,"pending publication stride/count is invalid");
        if(runtime_failed())return;return;
      end
      run.ticks=checked_add(run.ticks,run.step_ticks,scope_id);
      if(runtime_failed())return;
      run.count=checked_sub(run.count,1,scope_id);
      if(runtime_failed())return;
      buffer[0]=run;
    end
  endtask
