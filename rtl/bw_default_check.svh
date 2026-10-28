// Scope-owned evidence storage stays independent of historical failures in
// other typed scopes. Truly shared report totals retain the package helpers.
function automatic bw_u64_t default_add(int index,bw_u64_t value,bw_u64_t increment);
  logic [64:0] wide;
  if(scope_failed(scopes[index].kind,scopes[index].id))return value;
  if($isunknown({value,increment}))begin
    runtime_scope_error(scopes[index].kind,scopes[index].id,"INTEGER_UNKNOWN","owner=default-check addition operand unknown");
    return value;
  end
  wide={1'b0,value}+{1'b0,increment};
  if(wide[64])begin
    runtime_scope_error(scopes[index].kind,scopes[index].id,"INTEGER_OVERFLOW",
      $sformatf("owner=default-check addition a=%0d b=%0d",value,increment));
    return value;
  end
  return wide[63:0];
endfunction

function automatic void default_growth(int index,int current_size,string resource,bw_u64_t ticks);
  string id,key;
  id=scopes[index].id;key=scope_key(scopes[index].kind,id);
  if(scope_failed(scopes[index].kind,id))return;
  if(current_size<0 || current_size==32'sh7fffffff)begin
    runtime_scope_error(scopes[index].kind,id,"STORAGE_RANGE",
      $sformatf("resource=%s entries=%0d requested=1 original_ticks=%0d",resource,current_size,ticks));
    return;
  end
`ifdef BW_MON_TEST_SCHEDULING
  if(!bw_test_storage_peak.exists(resource) || current_size+1>bw_test_storage_peak[resource])
    bw_test_storage_peak[resource]=current_size+1;
`endif
`ifdef BW_MON_TEST_FAULTS
  // Use the established typed key: a same-ID group must not consume a point's
  // allocation rejection. This is the existing test-only fault mechanism.
  if(injected_growth_failures.exists(key) && injected_growth_failures[key].exists(resource))begin
    injected_growth_failures[key].delete(resource);
    runtime_scope_error(scopes[index].kind,id,"STORAGE_FAILURE",
      $sformatf("resource=%s entries=%0d requested=1 original_ticks=%0d injected=1",resource,current_size,ticks));
  end
`endif
endfunction

// Private implementation of the fixed per-platform check, inside bw_check_report.
// Raw rows are retained until episode settlement. Equal-valued rows compress
// only when every original endpoint, cycle position and sequence is affine.
virtual function void analysis_scope(bw_scope_t kind,string id,bit enabled,
    bw_basis_t basis,bw_u64_t width,bw_u64_t stride);
  int index;
  index=find_scope(kind,id);
  if(index<0)return;
  default_scopes[index].enabled=enabled;
  default_scopes[index].basis=basis;
  default_scopes[index].width=width;default_scopes[index].stride=stride;
endfunction

function automatic bw_check_window_t default_row(default_run_t run,bw_u64_t offset);
  bw_check_window_t row;
  row=run.first;
  if(run.count>1)begin
    row.seq+=offset*((run.last.seq-run.first.seq)/(run.count-1));
    row.ticks+=offset*((run.last.ticks-run.first.ticks)/(run.count-1));
    row.left_ticks+=offset*((run.last.left_ticks-run.first.left_ticks)/(run.count-1));
    row.u+=offset*((run.last.u-run.first.u)/(run.count-1));
    row.left_u+=offset*((run.last.left_u-run.first.left_u)/(run.count-1));
  end
  return row;
endfunction

virtual function void submit_window(string id,bw_check_window_t sample);
  int index,last;
  default_run_t run;
  bw_check_window_t previous;
  bit extend_run;
  index=find_scope(sample.scope_kind,id);
  if(index<0 || scopes[index].done || totals.finalized || scope_failed(scopes[index].kind,scopes[index].id) || sample.seq==0)return;
  if(default_scopes[index].have_seq && sample.seq<=default_scopes[index].last_seq)return;
  sample.valid=sample.valid && sample.full && sample.bytes_complete && sample.denominator_valid && !sample.foreign_activity;
  if(!finite_real(sample.value) || sample.value<0)sample.valid=0;
  last=default_scopes[index].raw.size()-1;extend_run=0;
  if(last>=0)begin
    run=default_scopes[index].raw[last];previous=run.last;
    extend_run=sample.stats_epoch==previous.stats_epoch && sample.episode_id==previous.episode_id &&
      sample.seq==previous.seq+1 && sample.valid==previous.valid &&
      sample.full==previous.full && sample.bytes_complete==previous.bytes_complete &&
      sample.denominator_valid==previous.denominator_valid && sample.foreign_activity==previous.foreign_activity &&
      sample.reset_coverage==previous.reset_coverage &&
      $realtobits(sample.value)==$realtobits(previous.value) &&
      sample.ticks>previous.ticks && sample.left_ticks>=previous.left_ticks &&
      sample.u>previous.u && sample.left_u>=previous.left_u;
    if(extend_run && run.count>1)extend_run=
      sample.ticks-previous.ticks==(run.last.ticks-run.first.ticks)/(run.count-1) &&
      sample.left_ticks-previous.left_ticks==(run.last.left_ticks-run.first.left_ticks)/(run.count-1) &&
      sample.u-previous.u==(run.last.u-run.first.u)/(run.count-1) &&
      sample.left_u-previous.left_u==(run.last.left_u-run.first.left_u)/(run.count-1);
  end
  if(extend_run)begin
    run.last=sample;run.count=default_add(index,run.count,1);
    if(scope_failed(scopes[index].kind,scopes[index].id))return;
    default_scopes[index].raw[last]=run;
  end else begin
    default_growth(index,default_scopes[index].raw.size(),"default.raw",sample.ticks);
    if(scope_failed(scopes[index].kind,scopes[index].id))return;
    run.first=sample;run.last=sample;run.count=1;default_scopes[index].raw.push_back(run);
  end
  default_scopes[index].have_seq=1;default_scopes[index].last_seq=sample.seq;
endfunction

function automatic bit default_result(int index,bw_episode_result_t episode,
    bw_phase_result_t platform,bit have_platform);
  bw_check_window_t row,reference[$];
  stage_handoff_t handoff,own_handoff;
  stage_step_t step;
  int next_platform;
  bw_u64_t terminal,handoff_phase;
  default_identity_t identity;
  bw_u64_t width,min_span,start_tick,end_tick,reference_end_tick,check_count,first_u,last_u;
  bw_u64_t run_count,run_first,run_last,runs,longest_count,longest_first,longest_last,longest_span;
  bw_u64_t reference_first_seq,reference_last_seq,reference_first_u,reference_last_u,previous_seq,exclusion_count,excluded_left,excluded_right;
  real baseline,deviation,maximum;
  bit reference_valid,quality,failed,exempt,over;
  string reason,conclusion,reference_seqs,baseline_text,threshold_text,maximum_text,percent_text,steady_text;
  if(scope_disabled(scopes[index].kind,scopes[index].id))return 0;
  identity='{epoch:episode.stats_epoch,episode:episode.episode_id,platform:have_platform ? platform.phase_id : 0};
  if(default_scopes[index].have_default_identity && identity<=default_scopes[index].default_identity)return 1;
  width=default_scopes[index].width;
  min_span=default_scopes[index].stride>width/5 ? width : 5*default_scopes[index].stride;
  if(default_scopes[index].basis==BW_NS)begin width*=BW_TICKS_PER_NS;min_span*=BW_TICKS_PER_NS;end
  start_tick=platform.start_ticks;
  terminal=episode.tail_known ? episode.tail_ticks : episode.last_ticks;
  end_tick=terminal;handoff_phase=0;next_platform=-1;
  step.valid=0;
  if(have_platform)foreach(default_scopes[index].phases[p])begin
    if(default_scopes[index].phases[p].stats_epoch==episode.stats_epoch &&
       default_scopes[index].phases[p].episode_id==episode.episode_id &&
       default_scopes[index].phases[p].phase_kind==BW_PHASE_STEADY &&
       default_scopes[index].phases[p].start_ticks>platform.start_ticks)begin
      if(next_platform<0)next_platform=p;
      handoff=default_scopes[index].handoff(default_scopes[index].phases[p],terminal);
      if(handoff.valid)begin
        end_tick=default_scopes[index].phases[p].start_ticks;
        handoff_phase=default_scopes[index].phases[p].phase_id;break;
      end
    end
  end
  if(next_platform>=0)begin
    step=default_scopes[index].step(platform,default_scopes[index].phases[next_platform],terminal);
    $display("BW_STAGE_STEP scope_kind=%0d scope=%s epoch=%0d episode=%0d old_platform=%0d new_platform=%0d valid=%0b reason=%s old_support_first=%0d old_support_last=%0d old_min=%.17g old_max=%.17g new_support_first=%0d new_support_last=%0d new_min=%.17g new_max=%.17g bridge_first_seq=%0d bridge_last_seq=%0d bridge_start=%0d bridge_end=%0d bridge_span=%0d bridge_limit=%0d arrived_ticks=%0d wait_end_ticks=%0d exclusion_start_ticks=%0d exclusion_end_ticks=%0d retained_start_ticks=%0d retained_end_ticks=%0d",
      scopes[index].kind,scopes[index].id,episode.stats_epoch,episode.episode_id,platform.phase_id,
      default_scopes[index].phases[next_platform].phase_id,step.valid,step.reason,
      platform.support_first_seq,platform.support_last_seq,platform.support_min_gbps,platform.support_max_gbps,
      default_scopes[index].phases[next_platform].support_first_seq,default_scopes[index].phases[next_platform].support_last_seq,
      default_scopes[index].phases[next_platform].support_min_gbps,default_scopes[index].phases[next_platform].support_max_gbps,
      step.bridge_first_seq,step.bridge_last_seq,step.bridge_start,step.bridge_end,step.bridge_span,
      default_scopes[index].logical_width()+default_scopes[index].logical_stride(),step.arrived_ticks,step.end_ticks,
      step.start_ticks,step.end_ticks,platform.start_ticks,step.valid ? step.start_ticks : end_tick);
  end
  own_handoff='{default:0};
  if(have_platform)own_handoff=default_scopes[index].handoff(platform,terminal);
  if(have_platform)$display("BW_STAGE_HANDOFF scope_kind=%0d scope=%s epoch=%0d episode=%0d platform=%0d final_start_ticks=%0d final_end_ticks=%0d valid=%0b first_seq=%0d last_seq=%0d count=%0d first_u=%0d last_u=%0d span=%0d required=%0d reason=%s",
    scopes[index].kind,scopes[index].id,episode.stats_epoch,episode.episode_id,platform.phase_id,
    platform.start_ticks,platform.end_ticks<terminal ? platform.end_ticks : terminal,
    own_handoff.valid,own_handoff.first_seq,own_handoff.last_seq,own_handoff.count,
    own_handoff.first_u,own_handoff.last_u,own_handoff.last_u-own_handoff.first_u,
    default_scopes[index].logical_width(),own_handoff.valid ? "CONTINUOUS_FINAL_PLATFORM" : "FINAL_PLATFORM_INSUFFICIENT");
  reference_end_tick=platform.end_ticks<end_tick ? platform.end_ticks : end_tick;
  baseline=0;reference_valid=0;maximum=0;check_count=0;first_u=0;last_u=0;
  reference_first_seq=0;reference_last_seq=0;reference_first_u=0;reference_last_u=0;reference_seqs="";
  run_count=0;run_first=0;run_last=0;runs=0;longest_count=0;longest_first=0;longest_last=0;longest_span=0;
  previous_seq=0;exclusion_count=step.valid ? 1 : 0;
  failed=0;
  // A qualified handoff closes this owned interval independently of later
  // terminal uncertainty. In-interval raw gaps still set quality below.
  quality=(handoff_phase==0 && (episode.status!==BW_EPISODE_COMPLETE ||
    !episode.tail_known || !episode.last_known)) ||
    (have_platform && (!platform.bytes_complete || !platform.end_known));
  reason=have_platform ? "REFERENCE_INSUFFICIENT" : (episode.episode_id==0 ? "NO_EPISODE" : "NO_CONFIRMED_STEADY");
  if(have_platform)foreach(default_scopes[index].phases[p])begin
    if(default_scopes[index].phases[p].stats_epoch==episode.stats_epoch &&
       default_scopes[index].phases[p].episode_id==episode.episode_id &&
       default_scopes[index].confirmed_transition(default_scopes[index].phases[p],terminal))begin
      excluded_left=default_scopes[index].phases[p].start_ticks>start_tick ?
        default_scopes[index].phases[p].start_ticks : start_tick;
      excluded_right=default_scopes[index].phases[p].end_ticks<end_tick ?
        default_scopes[index].phases[p].end_ticks : end_tick;
      if(excluded_right>excluded_left)begin
        exclusion_count=default_add(index,exclusion_count,1);
        $display("BW_DEFAULT_EXCLUSION scope_kind=%0d scope=%s epoch=%0d episode=%0d platform=%0d source_phase=%0d phase_kind=%0d start_ticks=%0d end_ticks=%0d reason=CONFIRMED_PHASE",
          scopes[index].kind,scopes[index].id,episode.stats_epoch,episode.episode_id,platform.phase_id,
          default_scopes[index].phases[p].phase_id,default_scopes[index].phases[p].phase_kind,excluded_left,excluded_right);
      end
    end
  end
  if(have_platform && platform.start_known && reference_end_tick>platform.start_ticks)begin
    // The earliest consecutive six full final-contained rows establish B.
    foreach(default_scopes[index].raw[r])begin
      for(bw_u64_t n=0;n<default_scopes[index].raw[r].count;n++)begin
        row=default_row(default_scopes[index].raw[r],n);
        if(row.stats_epoch!=episode.stats_epoch || row.episode_id!=episode.episode_id ||
           row.ticks<platform.start_ticks || row.ticks>=reference_end_tick)continue;
        if(!row.valid || row.left_ticks<platform.start_ticks)begin reference.delete();continue;end
        if(reference.size()!=0 && row.seq!=reference[$].seq+1)reference.delete();
        reference.push_back(row);
        if(reference.size()>6)row=reference.pop_front();
        if(reference.size()==6 && reference[5].u-reference[0].u>=min_span)begin
          foreach(reference[j])begin
            baseline+=reference[j].value;
            reference_seqs={reference_seqs,j==0 ? "" : ",",$sformatf("%0d",reference[j].seq)};
          end
          baseline/=6.0;
          reference_first_seq=reference[0].seq;reference_last_seq=reference[5].seq;
          reference_first_u=reference[0].u;reference_last_u=reference[5].u;
          reference_valid=finite_real(baseline) && baseline>=0;break;
        end
      end
      if(reference_valid)break;
    end
    if(!reference_valid && reference.size()!=0)begin
      foreach(reference[j])reference_seqs={reference_seqs,j==0 ? "" : ",",$sformatf("%0d",reference[j].seq)};
      reference_first_seq=reference[0].seq;reference_last_seq=reference[$].seq;
      reference_first_u=reference[0].u;reference_last_u=reference[$].u;
    end
    if(reference_valid && baseline==0)reason="ZERO_REFERENCE";
    if(reference_valid && baseline>0)begin
      foreach(default_scopes[index].raw[r])begin
        for(bw_u64_t n=0;n<default_scopes[index].raw[r].count;n++)begin
          row=default_row(default_scopes[index].raw[r],n);
          if(row.stats_epoch!=episode.stats_epoch || row.episode_id!=episode.episode_id ||
             row.ticks<start_tick || row.ticks>=end_tick)continue;
          if(previous_seq!=0 && row.seq!=previous_seq+1)begin quality=1;run_count=0;end
          previous_seq=row.seq;
          exempt=step.valid && row.ticks>=step.start_ticks && row.ticks<step.end_ticks;
          foreach(default_scopes[index].phases[p])begin
            if(default_scopes[index].phases[p].stats_epoch==episode.stats_epoch &&
               default_scopes[index].phases[p].episode_id==episode.episode_id &&
               default_scopes[index].confirmed_transition(default_scopes[index].phases[p],terminal) &&
               row.ticks>=default_scopes[index].phases[p].start_ticks &&
               row.ticks<default_scopes[index].phases[p].end_ticks)exempt=1;
          end
          if(!row.valid || exempt)begin
            if(!row.valid)quality=1;
            run_count=0;continue;
          end
          if(check_count==0)first_u=row.u;
          last_u=row.u;check_count=default_add(index,check_count,1);
          deviation=$abs(row.value-baseline);
          if(deviation>maximum)maximum=deviation;
          over=deviation>0.05*baseline;
          if(!over)begin run_count=0;continue;end
          if(run_count==0)begin run_first=row.u;runs=default_add(index,runs,1);end
          run_last=row.u;run_count=default_add(index,run_count,1);
          if(scope_failed(scopes[index].kind,scopes[index].id))return 0;
          if(run_last-run_first>longest_span || (run_last-run_first==longest_span && run_count>longest_count))begin
            longest_count=run_count;longest_first=run_first;longest_last=run_last;longest_span=run_last-run_first;
          end
          if(run_count>=2 && run_last-run_first>=width)failed=1;
        end
      end
      if(failed)reason="SUSTAINED_EXCEEDANCE";
      else if(quality)reason="OBSERVATION_INCOMPLETE";
      else if(check_count<2 || last_u-first_u<width)reason="CHECK_COVERAGE_INSUFFICIENT";
      else reason="NONE";
    end
  end
  if(failed)begin conclusion="FAIL";totals.fail_count=checked_add(totals.fail_count,1,scopes[index].id);end
  else if(reason!="NONE")begin conclusion="WARNING";totals.warning_count=checked_add(totals.warning_count,1,scopes[index].id);end
  else begin conclusion="PASS";totals.pass_count=checked_add(totals.pass_count,1,scopes[index].id);end
  if(scope_failed(scopes[index].kind,scopes[index].id))return 0;
  baseline_text=reference_valid ? $sformatf("%.17g",baseline) : "UNAVAILABLE";
  threshold_text=reference_valid && baseline>0 ? $sformatf("%.17g",0.05*baseline) : "UNAVAILABLE";
  maximum_text=reference_valid && baseline>0 ? $sformatf("%.17g",maximum) : "UNAVAILABLE";
  percent_text=reference_valid && baseline>0 ? $sformatf("%.17g",100.0*(maximum/baseline)) : "UNAVAILABLE";
  steady_text=platform.bandwidth_valid ? $sformatf("%.17g",platform.bandwidth_gbps) : "UNAVAILABLE";
  $display("BW_DEFAULT_CHECK scope_kind=%0d scope=%s epoch=%0d episode=%0d platform=%0d metric=sustained_variation basis=%0d W=%0d S=%0d platform_start_ticks=%0d platform_end_ticks=%0d check_start_ticks=%0d check_end_ticks=%0d handoff_platform=%0d reference_valid=%0b reference_count=%0d reference_seqs=%s reference_first_seq=%0d reference_last_seq=%0d reference_first_u=%0d reference_last_u=%0d reference_span=%0d B=%s steady_bandwidth_gbps=%s threshold_pct=5 threshold_gbps=%s max_deviation_gbps=%s max_deviation_pct=%s samples=%0d first_u=%0d last_u=%0d over_runs=%0d longest_count=%0d longest_first_u=%0d longest_last_u=%0d longest_span=%0d exclusion_count=%0d quality_incomplete=%0b episode_status=%0d episode_reason=%s platform_bytes_complete=%0b platform_start_known=%0b platform_end_known=%0b episode_bytes_complete=%0b episode_first_known=%0b episode_last_known=%0b episode_tail_known=%0b conclusion=%s reason=%s",
    scopes[index].kind,scopes[index].id,episode.stats_epoch,episode.episode_id,platform.phase_id,
    default_scopes[index].basis,default_scopes[index].width,default_scopes[index].stride,
    platform.start_ticks,platform.end_ticks,start_tick,end_tick,handoff_phase,reference_valid,reference_valid ? 6 : reference.size(),
    reference_seqs,reference_first_seq,reference_last_seq,reference_first_u,reference_last_u,reference_last_u-reference_first_u,
    baseline_text,steady_text,threshold_text,maximum_text,percent_text,
    check_count,first_u,last_u,runs,longest_count,longest_first,longest_last,longest_span,exclusion_count,quality,episode.status,episode_reason_name(episode.reason),platform.bytes_complete,platform.start_known,platform.end_known,episode.bytes_complete,
    episode.first_known,episode.last_known,episode.tail_known,conclusion,reason);
  default_scopes[index].have_default_identity=1;default_scopes[index].default_identity=identity;
  return 1;
endfunction

function automatic bit settle_default_episode(int index,bw_episode_result_t episode);
  bit found;
  bw_phase_result_t empty_platform;
  if(scope_disabled(scopes[index].kind,scopes[index].id))return 0;
  if(!default_scopes[index].enabled)return 1;
  found=0;
  foreach(default_scopes[index].phases[p])begin
    if(default_scopes[index].phases[p].stats_epoch==episode.stats_epoch &&
       default_scopes[index].phases[p].episode_id==episode.episode_id &&
       default_scopes[index].phases[p].phase_kind==BW_PHASE_STEADY)begin
      if(!default_result(index,episode,default_scopes[index].phases[p],1))return 0;
      found=1;
    end
  end
  if(!found && !default_result(index,episode,empty_platform,0))return 0;
  return 1;
endfunction
