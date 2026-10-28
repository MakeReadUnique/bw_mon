// Private phase attribution. This owner sees original publications, frozen
// recognition support and final bounds only. It has no checker reference,
// tolerance, performance verdict or authority to move a phase boundary.
typedef struct {
  bit valid;
  bw_u64_t first_seq,last_seq,count,first_u,last_u,first_ticks,last_ticks;
} stage_handoff_t;
typedef struct {
  bit valid;
  string reason;
  bw_u64_t start_ticks,end_ticks,bridge_first_seq,bridge_last_seq;
  bw_u64_t bridge_start,bridge_end,bridge_span,arrived_ticks;
} stage_step_t;

class bw_stage_evidence;
  bw_basis_t basis;
  bw_u64_t width,stride;
  default_run_t raw[$];
  bw_phase_result_t phases[$];

  function bw_u64_t logical_width();
    return basis==BW_NS ? width*BW_TICKS_PER_NS : width;
  endfunction
  function bw_u64_t logical_stride();
    return basis==BW_NS ? stride*BW_TICKS_PER_NS : stride;
  endfunction
  function bw_check_window_t row_at(default_run_t run,bw_u64_t offset);
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
  function bit find_seq(bw_u64_t seq,output bw_check_window_t row);
    foreach(raw[r])if(seq>=raw[r].first.seq && seq<=raw[r].last.seq)begin
      row=row_at(raw[r],seq-raw[r].first.seq);return row.seq==seq;
    end
    return 0;
  endfunction
  function bit publication_successor(bw_check_window_t a,bw_check_window_t b);
    return a.valid && b.valid && a.stats_epoch==b.stats_epoch && a.episode_id==b.episode_id &&
      b.seq==a.seq+1 && b.u>a.u && b.ticks>a.ticks;
  endfunction
  function bit continuous(bw_check_window_t a,bw_check_window_t b);
    // A normal-step bridge/support cannot cross known member reset coverage.
    return publication_successor(a,b) && !a.reset_coverage && !b.reset_coverage;
  endfunction
  function bit same_episode(bw_check_window_t row,bw_phase_result_t p);
    return row.stats_epoch==p.stats_epoch && row.episode_id==p.episode_id;
  endfunction
  function stage_handoff_t handoff(bw_phase_result_t p,bw_u64_t terminal);
    stage_handoff_t result;
    bw_check_window_t row,previous;
    bw_u64_t stop;
    // Unknown terminal tail does not erase a known prefix. The caller's
    // trusted cutoff clips the final interval; only contained publications
    // contribute, and the terminal platform still carries incomplete quality.
    result='{default:0};stop=p.end_ticks<terminal ? p.end_ticks : terminal;
    if(!p.start_known || stop<=p.start_ticks)return result;
    foreach(raw[r])for(bw_u64_t n=0;n<raw[r].count;n++)begin
      row=row_at(raw[r],n);
      if(!same_episode(row,p) || row.ticks<p.start_ticks || row.ticks>=stop)continue;
      // Known member resets retain known byte-complete publications. They do
      // not interrupt the group episode or invalidate handoff evidence.
      if(!row.valid)begin result.count=0;continue;end
      if(result.count!=0 && !publication_successor(previous,row))result.count=0;
      if(result.count==0)begin
        result.first_seq=row.seq;result.first_u=row.u;result.first_ticks=row.ticks;
      end
      result.count++;result.last_seq=row.seq;result.last_u=row.u;result.last_ticks=row.ticks;
      previous=row;
      if(result.count>=2 && result.last_u-result.first_u>=logical_width())begin result.valid=1;return result;end
    end
    return result;
  endfunction
  function bit support_valid(bw_phase_result_t p,bw_u64_t terminal,bit allow_member_reset=0);
    bw_check_window_t row,previous,first;
    bw_u64_t stop,min_span;
    real low,high;
    stop=p.end_ticks<terminal ? p.end_ticks : terminal;
    min_span=logical_stride()>logical_width()/5 ? logical_width() : 5*logical_stride();
    if(p.support_count!=7 || p.support_last_seq<p.support_first_seq ||
       p.support_last_seq-p.support_first_seq!=6)return 0;
    for(int i=0;i<7;i++)begin
      if(!find_seq(p.support_first_seq+i,row) || !same_episode(row,p) ||
         !row.valid || (!allow_member_reset && row.reset_coverage) || row.ticks>=stop || row.ticks>p.confirmation_ticks)return 0;
      if(i==0)begin first=row;low=row.value;high=row.value;end
      else if(!publication_successor(previous,row))return 0;
      if(row.value<low)low=row.value;
      if(row.value>high)high=row.value;
      previous=row;
    end
    return row.u-first.u>=min_span && low==p.support_min_gbps && high==p.support_max_gbps;
  endfunction
  function bit confirmed_transition(bw_phase_result_t p,bw_u64_t terminal);
    return p.phase_kind inside {BW_PHASE_RAMP,BW_PHASE_FALL} &&
      p.start_known && p.start_ticks<p.end_ticks &&
      p.start_ticks<terminal && support_valid(p,terminal,1);
  endfunction
  function bit in_envelope(bw_check_window_t row,bw_phase_result_t p);
    return row.value>=p.support_min_gbps && row.value<=p.support_max_gbps;
  endfunction
  function stage_step_t step(bw_phase_result_t old_platform,bw_phase_result_t new_platform,bw_u64_t terminal);
    stage_step_t result;
    stage_handoff_t old_handoff,new_handoff;
    bw_check_window_t row,previous,arrived,next_row;
    bit found;
    int direction;
    result.valid=0;result.reason="PLATFORM_OR_SUPPORT_INSUFFICIENT";
    old_handoff=handoff(old_platform,terminal);new_handoff=handoff(new_platform,terminal);
    if(!old_handoff.valid || !new_handoff.valid || !support_valid(old_platform,terminal) ||
       !support_valid(new_platform,terminal))return result;
    foreach(phases[p])if(phases[p].stats_epoch==old_platform.stats_epoch &&
      phases[p].episode_id==old_platform.episode_id && phases[p].start_known && phases[p].end_known &&
      phases[p].phase_kind inside {BW_PHASE_RAMP,BW_PHASE_FALL} &&
      phases[p].start_ticks<new_platform.start_ticks && phases[p].end_ticks>old_platform.start_ticks)begin
      result.reason="INDEPENDENT_RAMP_FALL";return result;
    end
    direction=new_platform.support_min_gbps>old_platform.support_max_gbps ? 1 :
      (new_platform.support_max_gbps<old_platform.support_min_gbps ? -1 : 0);
    result.reason="SUPPORT_ENVELOPES_OVERLAP";
    if(direction==0)return result;
    found=0;
    foreach(raw[r])begin
      if(raw[r].first.ticks<=new_platform.start_ticks && raw[r].last.ticks>=new_platform.start_ticks)begin
        bw_u64_t offset;
        offset=raw[r].count>1 ? (new_platform.start_ticks-raw[r].first.ticks)/
          ((raw[r].last.ticks-raw[r].first.ticks)/(raw[r].count-1)) : 0;
        row=row_at(raw[r],offset);
        found=row.ticks==new_platform.start_ticks && same_episode(row,new_platform);break;
      end
    end
    result.reason="NEW_BOUNDARY_UNSUPPORTED";
    if(!found || !row.valid || row.reset_coverage || !in_envelope(row,new_platform))return result;
    // Walk only a contiguous suffix already at the independently known new
    // level. Its duration is recognition waiting, not the physical bridge.
    while(row.seq>0 && find_seq(row.seq-1,previous) &&
      previous.ticks>old_platform.start_ticks && continuous(previous,row) && in_envelope(previous,new_platform))row=previous;
    arrived=row;next_row=row;
    result.reason="NO_CONTINUOUS_MONOTONIC_BRIDGE";
    while(next_row.seq>0)begin
      if(!find_seq(next_row.seq-1,previous) || previous.ticks<old_platform.start_ticks ||
         !continuous(previous,next_row) || direction*(next_row.value-previous.value)<0 ||
         arrived.u-previous.u>logical_width()+logical_stride())return result;
      if(in_envelope(previous,old_platform))begin
        if(next_row.ticks>=new_platform.start_ticks)begin result.reason="NO_PREBOUNDARY_EXCLUSION";return result;end
        result.valid=1;result.reason="INDEPENDENT_NORMAL_STEP";
        result.start_ticks=next_row.ticks;result.end_ticks=new_platform.start_ticks;
        result.bridge_first_seq=previous.seq;result.bridge_last_seq=arrived.seq;
        result.bridge_start=previous.u;result.bridge_end=arrived.u;result.bridge_span=arrived.u-previous.u;
        result.arrived_ticks=arrived.ticks;return result;
      end
      next_row=previous;
    end
    return result;
  endfunction
endclass
