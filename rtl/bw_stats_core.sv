module bw_stats_core #(
  parameter bw_mon_pkg::bw_basis_t WINDOW_BASIS = bw_mon_pkg::BW_NS,
  parameter bw_mon_pkg::bw_u64_t WINDOW_WIDTH = 0,
  parameter bw_mon_pkg::bw_u64_t UPDATE_STRIDE = 0,
  parameter bit EPISODE_ENABLE = 0,
  parameter logic [63:0] SILENCE_THRESHOLD = 0,
  parameter bit PHASE_ENABLE = 0,
  parameter logic [63:0] PHASE_N = 0,
  parameter logic [63:0] PHASE_MIN_SPAN = 0,
  parameter logic [63:0] PHASE_K = 0,
  parameter real PHASE_STEADY_ENTER_ABS = -1.0,
  parameter real PHASE_STEADY_ENTER_REL = -1.0,
  parameter real PHASE_STEADY_EXIT_ABS = -1.0,
  parameter real PHASE_STEADY_EXIT_REL = -1.0,
  parameter real PHASE_RMS_ENTER_ABS = -1.0,
  parameter real PHASE_RMS_ENTER_REL = -1.0,
  parameter real PHASE_RMS_EXIT_ABS = -1.0,
  parameter real PHASE_RMS_EXIT_REL = -1.0,
  parameter real PHASE_TREND_ABS = -1.0,
  parameter real PHASE_TREND_REL = -1.0
) (
  input string scope_id,
  input bw_mon_pkg::bw_scope_t scope_kind = bw_mon_pkg::BW_POINT,
  input bw_mon_pkg::bw_record_t record,
  input bit record_toggle,
  input logic stats_reset_n = 1'b1,
  input bw_mon_pkg::bw_u64_t progress_watermark_ticks = bw_mon_pkg::BW_U64_MAX,
  input bw_mon_pkg::bw_control_t member_control = '0,
  input bit member_control_toggle = 1'b0,
  output bw_mon_pkg::bw_u64_t accepted_record_seq = 0,
  output bw_mon_pkg::bw_u64_t accepted_control_count = 0,
  output bw_mon_pkg::bw_u64_t stats_epoch = 0,
  output bw_mon_pkg::bw_u64_t result_seq = 0,
  output bw_mon_pkg::bw_u64_t total_bytes = 0,
  output bw_mon_pkg::bw_u64_t total_events = 0,
  output bw_mon_pkg::bw_u64_t window_start_ticks = 0,
  output bw_mon_pkg::bw_u64_t window_end_ticks = 0,
  output bw_mon_pkg::bw_u64_t window_start_cycle = 0,
  output bw_mon_pkg::bw_u64_t window_end_cycle = 0,
  output bw_mon_pkg::bw_u64_t coverage_ticks = 0,
  output bw_mon_pkg::bw_u64_t coverage_cycles = 0,
  output bw_mon_pkg::bw_u64_t window_bytes = 0,
  output bw_mon_pkg::bw_u64_t window_events = 0,
  output real bandwidth_gbps = 0.0,
  output real bytes_per_cycle = 0.0,
  output bit window_warmup = 1,
  output bit window_full = 0,
  output bit bytes_complete = 1,
  output bit events_complete = 1,
  output bit denominator_valid = 0,
  output bit window_valid = 0,
  output bit member_reset_coverage = 0,
  output bit episode_active = 0,
  output bw_mon_pkg::bw_episode_status_t episode_status = bw_mon_pkg::BW_EPISODE_NONE,
  output bw_mon_pkg::bw_u64_t episode_id = 0,
  output bw_mon_pkg::bw_u64_t episode_result_seq = 0,
  output bw_mon_pkg::bw_u64_t episode_first_ticks = 0,
  output bw_mon_pkg::bw_u64_t episode_last_ticks = 0,
  output bw_mon_pkg::bw_u64_t episode_tail_ticks = 0,
  output bw_mon_pkg::bw_u64_t episode_confirmation_ticks = 0,
  output bw_mon_pkg::bw_u64_t episode_first_cycle = 0,
  output bw_mon_pkg::bw_u64_t episode_last_cycle = 0,
  output bw_mon_pkg::bw_u64_t episode_tail_cycle = 0,
  output bw_mon_pkg::bw_u64_t episode_bytes = 0,
  output bw_mon_pkg::bw_u64_t episode_events = 0,
  output bw_mon_pkg::bw_u64_t episode_duration_ticks = 0,
  output bit episode_first_known = 0,
  output bit episode_last_known = 0,
  output bit episode_tail_known = 0,
  output bit episode_bytes_complete = 1,
  output bit episode_events_complete = 1,
  output bit episode_member_reset_coverage = 0,
  output bit episode_duration_valid = 0,
  output bit episode_e2e_valid = 0,
  output real episode_e2e_gbps = 0.0,
  output bw_mon_pkg::bw_episode_result_t episode_result,
  output bw_mon_pkg::bw_phase_t phase_current = bw_mon_pkg::BW_PHASE_UNDETERMINED,
  output bw_mon_pkg::bw_phase_t phase_candidate = bw_mon_pkg::BW_PHASE_UNDETERMINED,
  output bit phase_active = 0,
  output bit phase_eligible = 0,
  output bit phase_evidence_continuous = 0,
  output bit phase_evidence_sufficient = 0,
  output bit phase_fit_valid = 0,
  output bw_mon_pkg::bw_u64_t phase_id = 0,
  output bw_mon_pkg::bw_u64_t phase_result_seq = 0,
  output bw_mon_pkg::bw_u64_t phase_window_seq = 0,
  output bw_mon_pkg::bw_u64_t phase_evidence_count = 0,
  output bw_mon_pkg::bw_u64_t phase_evidence_span = 0,
  output bw_mon_pkg::bw_u64_t phase_candidate_count = 0,
  output bw_mon_pkg::bw_u64_t phase_candidate_ticks = 0,
  output bw_mon_pkg::bw_u64_t phase_candidate_total_bytes = 0,
  output bw_mon_pkg::bw_u64_t phase_candidate_total_events = 0,
  output bw_mon_pkg::bw_u64_t phase_start_ticks = 0,
  output bw_mon_pkg::bw_u64_t phase_confirmation_ticks = 0,
  output real phase_fit_mean = 0.0,
  output real phase_fit_delta = 0.0,
  output real phase_fit_rms = 0.0,
  output bw_mon_pkg::bw_phase_result_t phase_result
);
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_record_t history[$];
  bw_record_t pending_frames[$];
  bw_u64_t pending_timers[$];
  typedef struct packed {
    bw_u64_t timestamp_ticks;
    logic reset_n;
  } reset_action_t;
  reset_action_t pending_resets[$];
  bw_control_t pending_member_controls[$];
  typedef struct packed {
    bw_u64_t start_ticks;
    bw_u64_t end_ticks;
    bit unknown_reset;
    bit known_reset;
  } quality_interval_t;
  typedef struct packed {
    bw_u64_t start_ticks;
    logic reset_n;
  } active_quality_t;
  quality_interval_t quality_intervals[$];
  active_quality_t active_quality[int];
  bw_u64_t member_control_sequences[int];
  bw_u64_t member_control_times[int];
  bw_u64_t requested_actions=0, consumed_actions=0;
  bw_u64_t timer_requests=0, timer_receipts=0, timer_schedule_seq=0;
  bw_u64_t stats_start_ticks;
  bw_u64_t last_assert_ticks=0;
  bit assertion_observed=0, reset_enqueued=0, reset_applied=0;
  logic observed_reset_n, current_reset_n=1'b1;
  bw_u64_t next_update_ticks;
  bw_u64_t retained_bytes = 0, retained_events = 0;
  bw_u64_t unknown_bytes = 0, unknown_events = 0, reset_entries = 0;
  bw_u64_t last_record_seq = 0;
  bw_u64_t last_frame_ticks = 0, last_edge_index = 0;
  // Idle edges are physical cycle boundaries too. Keep their integer times
  // separately from the sparse event/quality history used by both bases.
  bw_u64_t cycle_boundary_ticks[$];
  bw_u64_t boundary_first_cycle, cycle_origin, next_update_cycle;
  bit cycle_initialized = 0;
  bit initialized = 0;

  bit silence_active=0;
  bw_u64_t silence_start_ticks=0, silence_start_cycle=0;
  bw_u64_t silence_unknown_ticks=0;
  bit scheduled_episode_deadline_valid=0;
  bw_u64_t scheduled_episode_deadline=0;
  bw_u64_t episode_start_total_bytes=0, episode_end_total_bytes=0;
  bw_u64_t episode_start_total_events=0, episode_end_total_events=0;
  bit pre_episode_gap=0, observation_gap_active=0, gap_waits_for_edge=0;
  bit pending_sample_reset_coverage=0;
  quality_interval_t episode_quality_intervals[$];

  typedef struct {
    bw_u64_t ticks,basis_position;
    real value;
  } phase_sample_t;
  phase_sample_t phase_samples[$];
  typedef struct {
    bw_variation_result_t result;
    real m2;
  } variation_state_t;
  typedef struct {
    bw_u64_t ticks;
    real value;
    bit warmup,foreign_activity,unknown_observation,bad_denominator;
  } variation_sample_t;
  typedef struct {
    bw_phase_result_t fragment;
    variation_state_t stats;
  } pending_phase_t;
  pending_phase_t pending_phases[$];
  variation_sample_t episode_pending_samples[$],phase_pending_samples[$];
  variation_state_t episode_variation,phase_variation;
  bw_phase_result_t last_steady;
  bit last_steady_found=0;
  bw_u64_t raw_unknown_records=0,raw_unknown_event_records=0,raw_unknown_ticks=0,raw_quality_ticks=0;
  bw_u64_t phase_start_unknown_event_records=0,candidate_unknown_event_records=0,episode_end_unknown_event_records=0;
  bw_u64_t raw_reset_records=0,phase_start_reset_records=0,candidate_reset_records=0,episode_end_reset_records=0;
  bw_u64_t phase_start_unknown_records=0,phase_start_unknown_ticks=0;
  bw_u64_t candidate_unknown_records=0,candidate_unknown_ticks=0;
  bw_u64_t episode_end_unknown_records=0,episode_end_unknown_ticks=0;
  bw_u64_t phase_start_total_bytes=0,phase_start_total_events=0;
  real phase_confirmation_delta=0.0,phase_confirmation_rms=0.0;
  // Ordered episodes make this an exact compressed ownership query: every
  // retired episode's activity is at/before the latest retired transfer,
  // including a zero-byte event. Unknown evidence has a separate quality gate.
  bit retired_activity_valid=0;
  bw_u64_t retired_episode_id=0,retired_last_ticks=0,retired_last_cycle=0;

  function automatic bit foreign_activity();
    return retired_activity_valid && retired_episode_id!=episode_id &&
      ((WINDOW_BASIS==BW_NS && window_start_ticks<=retired_last_ticks) ||
       (WINDOW_BASIS==BW_CYCLE && window_start_cycle<=retired_last_cycle));
  endfunction

  function automatic bw_u64_t unknown_ticks_at(bw_u64_t tick);
    if(tick<raw_quality_ticks)begin
      core_error("METRIC_TIME",scope_id,$sformatf("snapshot=%0d quality_cursor=%0d",tick,raw_quality_ticks));
      return raw_unknown_ticks;
    end
    return unknown_episode_control() ? checked_add(raw_unknown_ticks,tick-raw_quality_ticks,scope_id) : raw_unknown_ticks;
  endfunction

  task automatic advance_raw_quality(bw_u64_t tick);
    // A known own reset suspends this statistical epoch. Member notifications
    // still advance their transport receipts and may describe earlier times.
    if(current_reset_n===1'b0)begin
      if(tick>raw_quality_ticks)raw_quality_ticks=tick;
      return;
    end
    raw_unknown_ticks=unknown_ticks_at(tick);raw_quality_ticks=tick;
  endtask

  function automatic bw_variation_result_t empty_variation_result();
    return '{window_basis:WINDOW_BASIS,window_width:WINDOW_WIDTH,update_stride:UPDATE_STRIDE,
      minmax_reason:BW_METRIC_NO_SAMPLES,stddev_reason:BW_METRIC_TOO_FEW_SAMPLES,
      cv_reason:BW_METRIC_TOO_FEW_SAMPLES,default:0};
  endfunction

  function automatic variation_state_t empty_variation();
    return '{result:empty_variation_result(),m2:0.0};
  endfunction

  function automatic bw_phase_result_t empty_phase_result();
    return '{scope_kind:scope_kind,phase_kind:BW_PHASE_UNDETERMINED,end_reason:BW_PHASE_CHANGE,
      episode_status:BW_EPISODE_NONE,duration_reason:BW_METRIC_BOUNDARY_UNKNOWN,
      bandwidth_reason:BW_METRIC_BOUNDARY_UNKNOWN,variation:empty_variation_result(),default:0};
  endfunction

  task automatic add_variation_sample(ref variation_state_t state,variation_sample_t sample);
    bw_u64_t n;
    real delta,new_mean,new_m2;
    if(sample.warmup)state.result.excluded_warmup=checked_add(state.result.excluded_warmup,1,scope_id);
    if(sample.foreign_activity)state.result.excluded_foreign=checked_add(state.result.excluded_foreign,1,scope_id);
    if(sample.unknown_observation && !sample.warmup && !sample.foreign_activity && !sample.bad_denominator)state.result.unknown_samples=checked_add(state.result.unknown_samples,1,scope_id);
    if(sample.bad_denominator)state.result.excluded_denominator=checked_add(state.result.excluded_denominator,1,scope_id);
    if(sample.warmup || sample.foreign_activity || sample.unknown_observation || sample.bad_denominator)return;
    n=checked_add(state.result.sample_count,1,scope_id);
    if(core_failure_seen)return;
    if(n==1)begin
      state.result.mean_gbps=sample.value;state.result.min_gbps=sample.value;state.result.max_gbps=sample.value;
      state.result.first_sample_ticks=sample.ticks;state.m2=0.0;
    end else begin
      delta=sample.value-state.result.mean_gbps;
      new_mean=state.result.mean_gbps+delta/real'(n);
      new_m2=state.m2+delta*(sample.value-new_mean);
      if(!finite_nonnegative_real(new_mean) || !finite_nonnegative_real(new_m2))begin
        core_error("METRIC_ARITHMETIC",scope_id,$sformatf("sample_ticks=%0d count=%0d mean=%0.17g m2=%0.17g value=%0.17g",sample.ticks,n,new_mean,new_m2,sample.value));
        return;
      end
      state.result.mean_gbps=new_mean;state.m2=new_m2;
      if(sample.value<state.result.min_gbps)state.result.min_gbps=sample.value;
      if(sample.value>state.result.max_gbps)state.result.max_gbps=sample.value;
    end
    state.result.sample_count=n;state.result.last_sample_ticks=sample.ticks;
    state.result.sample_span_ticks=sample.ticks-state.result.first_sample_ticks;
  endtask

  function automatic bw_variation_result_t final_variation(variation_state_t state,
      bit interval_known,bw_metric_reason_t interval_reason);
    bw_variation_result_t result;
    bw_metric_reason_t reason;
    result=state.result;result.interval_known=interval_known;
    result.coverage_complete=(result.unknown_samples==0 && result.excluded_denominator==0);
    reason=interval_reason;
    if(reason==BW_METRIC_OK && !interval_known)reason=BW_METRIC_BOUNDARY_UNKNOWN;
    if(reason==BW_METRIC_OK && !result.coverage_complete)reason=BW_METRIC_OBSERVATION_UNKNOWN;
    result.minmax_valid=(reason==BW_METRIC_OK && result.sample_count>=1);
    result.stddev_valid=(reason==BW_METRIC_OK && result.sample_count>=2);
    result.cv_valid=(result.stddev_valid && result.mean_gbps>0.0);
    result.minmax_reason=(reason!=BW_METRIC_OK) ? reason :
      (result.sample_count==0 ? BW_METRIC_NO_SAMPLES : BW_METRIC_OK);
    result.stddev_reason=(reason!=BW_METRIC_OK) ? reason :
      (result.sample_count<2 ? BW_METRIC_TOO_FEW_SAMPLES : BW_METRIC_OK);
    result.cv_reason=(reason!=BW_METRIC_OK) ? reason :
      (result.sample_count<2 ? BW_METRIC_TOO_FEW_SAMPLES :
       (result.mean_gbps==0.0 ? BW_METRIC_ZERO_MEAN : BW_METRIC_OK));
    result.stddev_gbps=result.stddev_valid ? $sqrt(state.m2/real'(result.sample_count)) : 0.0;
    result.cv_pct=result.cv_valid ? (result.stddev_gbps/result.mean_gbps)*100.0 : 0.0;
    if(!finite_nonnegative_real(result.stddev_gbps) || !finite_nonnegative_real(result.cv_pct))
      core_error("METRIC_ARITHMETIC",scope_id,$sformatf("count=%0d mean=%0.17g m2=%0.17g sigma=%0.17g cv=%0.17g",result.sample_count,result.mean_gbps,state.m2,result.stddev_gbps,result.cv_pct));
    return result;
  endfunction

  task automatic retain_variation_sample();
    variation_sample_t sample;
    if(!EPISODE_ENABLE || !episode_active)return;
    sample.ticks=window_end_ticks;sample.value=bandwidth_gbps;
    sample.warmup=!window_full;sample.foreign_activity=foreign_activity();
    sample.unknown_observation=!bytes_complete;sample.bad_denominator=!denominator_valid;
    check_queue_growth(episode_pending_samples.size(),scope_id);
    if(core_failure_seen)return;
    episode_pending_samples.push_back(sample);
    if(PHASE_ENABLE)begin
      check_queue_growth(phase_pending_samples.size(),scope_id);
      if(core_failure_seen)return;
      phase_pending_samples.push_back(sample);
    end
  endtask

  // Only samples inside already established coverage and outside the possible
  // backdated candidate suffix can enter irreversible online summaries.
  task automatic settle_variation(bw_u64_t covered_through,bit finishing=0);
    variation_sample_t sample;
    bit assigned_sample;
    while(episode_pending_samples.size()!=0 && episode_pending_samples[0].ticks<covered_through)begin
      sample=episode_pending_samples.pop_front();add_variation_sample(episode_variation,sample);
    end
    while(phase_pending_samples.size()!=0 && phase_pending_samples[0].ticks<covered_through)begin
      sample=phase_pending_samples[0];assigned_sample=0;
      foreach(pending_phases[i])begin
        if(sample.ticks>=pending_phases[i].fragment.start_ticks && sample.ticks<pending_phases[i].fragment.end_ticks)begin
          add_variation_sample(pending_phases[i].stats,sample);assigned_sample=1;break;
        end
      end
      if(!assigned_sample && phase_candidate_count!=0 && sample.ticks>=phase_candidate_ticks && !finishing)break;
      if(!assigned_sample && phase_active && sample.ticks>=phase_start_ticks)
        add_variation_sample(phase_variation,sample);
      sample=phase_pending_samples.pop_front();
    end
  endtask

  task automatic clear_phase_evidence();
    phase_samples.delete();phase_evidence_count=0;phase_evidence_span=0;
    phase_evidence_continuous=0;phase_evidence_sufficient=0;phase_fit_valid=0;
    phase_fit_mean=0.0;phase_fit_delta=0.0;phase_fit_rms=0.0;
    phase_candidate=BW_PHASE_UNDETERMINED;phase_candidate_count=0;phase_candidate_ticks=0;
    phase_candidate_total_bytes=0;phase_candidate_total_events=0;
  endtask

  task automatic begin_phase_episode();
    episode_pending_samples.delete();phase_pending_samples.delete();
    episode_variation=empty_variation();phase_variation=empty_variation();
    last_steady_found=0;last_steady=empty_phase_result();
    if(!PHASE_ENABLE)return;
    if(pending_phases.size()!=0)core_error("PHASE_STATE",scope_id,"unsettled phases at new episode");
    clear_phase_evidence();phase_current=BW_PHASE_UNDETERMINED;phase_active=0;
    phase_start_ticks=0;phase_confirmation_ticks=0;phase_eligible=0;
  endtask

  function automatic bit phase_reset_overlap(bw_u64_t left,bw_u64_t right);
    foreach(episode_quality_intervals[i])
      if(episode_quality_intervals[i].known_reset && episode_quality_intervals[i].start_ticks<right &&
         episode_quality_intervals[i].end_ticks>left)return 1;
    foreach(active_quality[key])
      if(active_quality[key].reset_n===1'b0 && active_quality[key].start_ticks<right)return 1;
    return 0;
  endfunction

  task automatic deliver_phase(bw_phase_result_t fragment,variation_state_t stats);
    bw_u64_t next_sequence;
    if(core_failure_seen)return;
    fragment.duration_valid=fragment.start_known && fragment.end_known && fragment.end_ticks>fragment.start_ticks;
    fragment.duration_ticks=fragment.duration_valid ? fragment.end_ticks-fragment.start_ticks : 0;
    fragment.duration_reason=fragment.duration_valid ? BW_METRIC_OK :
      (fragment.episode_status==BW_EPISODE_RESET_INTERRUPTED ? BW_METRIC_RESET :
       (fragment.episode_status==BW_EPISODE_TRUNCATED ? BW_METRIC_TRUNCATED : BW_METRIC_BOUNDARY_UNKNOWN));
    if(fragment.end_total_bytes<fragment.start_total_bytes || fragment.end_total_events<fragment.start_total_events)begin
      core_error("METRIC_ARITHMETIC",scope_id,"phase cumulative count moved backwards");
      return;
    end
    fragment.byte_count=fragment.end_total_bytes-fragment.start_total_bytes;
    fragment.event_count=fragment.end_total_events-fragment.start_total_events;
    fragment.bytes_complete=(fragment.start_unknown_records==fragment.end_unknown_records &&
      fragment.start_unknown_ticks==fragment.end_unknown_ticks);
    fragment.events_complete=(fragment.start_unknown_event_records==fragment.end_unknown_event_records &&
      fragment.start_unknown_ticks==fragment.end_unknown_ticks);
    fragment.member_reset_coverage=(fragment.start_reset_records!=fragment.end_reset_records) ||
      phase_reset_overlap(fragment.start_ticks,fragment.end_ticks);
    fragment.bandwidth_valid=fragment.duration_valid && fragment.bytes_complete;
    fragment.bandwidth_reason=!fragment.duration_valid ? fragment.duration_reason :
      (!fragment.bytes_complete ? BW_METRIC_BYTES_UNKNOWN : BW_METRIC_OK);
    fragment.bandwidth_gbps=fragment.bandwidth_valid ?
      real'(fragment.byte_count)*real'(BW_TICKS_PER_NS)/real'(fragment.duration_ticks) : 0.0;
    fragment.variation=final_variation(stats,fragment.duration_valid,fragment.duration_reason);
    if(!finite_nonnegative_real(fragment.bandwidth_gbps))core_error("METRIC_ARITHMETIC",scope_id,"phase bandwidth is not finite");
    if(core_failure_seen)return;
    next_sequence=checked_add(phase_result_seq,1,scope_id);
    if(core_failure_seen)return;
    phase_result_seq=next_sequence;
    fragment.result_seq=phase_result_seq;phase_result=fragment;
    if(fragment.phase_kind==BW_PHASE_STEADY)begin last_steady=fragment;last_steady_found=1;end
    emit_phase_result(scope_id,fragment);
  endtask

  task automatic close_phase(bw_u64_t end_tick,bw_u64_t end_bytes,bw_u64_t end_events,
                             bit end_known,bw_phase_end_t reason,
                             bw_u64_t end_unknown_records,bw_u64_t end_unknown_ticks,bw_u64_t end_unknown_event_records,bw_u64_t end_reset_records);
    bw_phase_result_t fragment;
    pending_phase_t pending;
    if(!PHASE_ENABLE || !phase_active || core_failure_seen)return;
    if(end_known && end_tick<=phase_start_ticks)begin phase_active=0;return;end
    fragment.scope_kind=scope_kind;fragment.stats_epoch=stats_epoch;
    fragment.episode_id=episode_id;fragment.phase_id=phase_id;fragment.result_seq=0;
    fragment.phase_kind=phase_current;fragment.end_reason=reason;fragment.episode_status=BW_EPISODE_ACTIVE;
    fragment.start_ticks=phase_start_ticks;fragment.end_ticks=end_tick;
    fragment.confirmation_ticks=phase_confirmation_ticks;
    fragment.start_total_bytes=phase_start_total_bytes;fragment.end_total_bytes=end_bytes;
    fragment.start_total_events=phase_start_total_events;fragment.end_total_events=end_events;
    fragment.start_known=1;fragment.end_known=end_known;
    fragment.start_unknown_records=phase_start_unknown_records;fragment.end_unknown_records=end_unknown_records;
    fragment.start_unknown_event_records=phase_start_unknown_event_records;fragment.end_unknown_event_records=end_unknown_event_records;
    fragment.start_reset_records=phase_start_reset_records;fragment.end_reset_records=end_reset_records;
    fragment.start_unknown_ticks=phase_start_unknown_ticks;fragment.end_unknown_ticks=end_unknown_ticks;
    fragment.confirmation_delta=phase_confirmation_delta;fragment.confirmation_rms=phase_confirmation_rms;
    check_queue_growth(pending_phases.size(),scope_id);
    if(core_failure_seen)return;
    pending.fragment=fragment;pending.stats=phase_variation;
    pending_phases.push_back(pending);phase_variation=empty_variation();phase_active=0;
  endtask

  task automatic flush_safe_phases();
    pending_phase_t pending;
    bw_u64_t known_covered_through;
    if(!episode_active)return;
    known_covered_through=episode_tail_known ? episode_tail_ticks : episode_last_ticks;
    settle_variation(known_covered_through);
    while(pending_phases.size()!=0 && pending_phases[0].fragment.end_known &&
          pending_phases[0].fragment.end_ticks<=known_covered_through)begin
      pending=pending_phases.pop_front();deliver_phase(pending.fragment,pending.stats);
    end
  endtask

  task automatic finish_episode_phases(bw_episode_status_t status,bw_u64_t observed_end);
    bw_phase_result_t fragment;
    pending_phase_t pending;
    bit known_end;
    bw_u64_t end_tick,end_bytes,end_events;
    if(core_failure_seen)return;
    flush_safe_phases();
    known_end=episode_tail_known && episode_last_known;
    end_tick=known_end ? episode_tail_ticks : observed_end;
    end_bytes=known_end ? episode_end_total_bytes : total_bytes;
    end_events=known_end ? episode_end_total_events : total_events;
    close_phase(end_tick,end_bytes,end_events,known_end,BW_PHASE_EPISODE_END,
      known_end ? episode_end_unknown_records : raw_unknown_records,
      known_end ? episode_end_unknown_ticks :
        (status==BW_EPISODE_COMPLETE ? silence_unknown_ticks : unknown_ticks_at(observed_end)),
      known_end ? episode_end_unknown_event_records : raw_unknown_event_records,
      known_end ? episode_end_reset_records : raw_reset_records);
    settle_variation(end_tick,1);
    while(pending_phases.size()!=0)begin
      pending=pending_phases.pop_front();fragment=pending.fragment;
      if(known_end)begin
        if(fragment.start_ticks>=end_tick)continue;
        if(fragment.end_ticks>end_tick)begin
          fragment.end_ticks=end_tick;fragment.end_total_bytes=end_bytes;fragment.end_total_events=end_events;
          fragment.end_reason=BW_PHASE_EPISODE_END;
          fragment.end_unknown_records=episode_end_unknown_records;fragment.end_unknown_ticks=episode_end_unknown_ticks;
          fragment.end_unknown_event_records=episode_end_unknown_event_records;fragment.end_reset_records=episode_end_reset_records;
        end
      end else fragment.end_known=0;
      fragment.episode_status=status;deliver_phase(fragment,pending.stats);
    end
    clear_phase_evidence();phase_active=0;phase_current=BW_PHASE_UNDETERMINED;phase_eligible=0;
  endtask

  task automatic break_phase_evidence(bw_u64_t at_ticks);
    close_phase(at_ticks,total_bytes,total_events,1,BW_PHASE_EVIDENCE_GAP,raw_unknown_records,unknown_ticks_at(at_ticks),raw_unknown_event_records,raw_reset_records);
    flush_safe_phases();clear_phase_evidence();
    phase_current=BW_PHASE_UNDETERMINED;phase_active=0;
    phase_start_ticks=0;phase_confirmation_ticks=0;
  endtask

  task automatic fit_phase_samples();
    real x,y,mean_x,mean_y_delta,xx,xy,slope,residual,sum_residual;
    real anchor_y;
    bw_u64_t origin;
    origin=phase_samples[0].ticks;anchor_y=phase_samples[0].value;
    mean_x=0.0;mean_y_delta=0.0;
    foreach(phase_samples[i])begin
      x=real'(phase_samples[i].ticks-origin)/real'(BW_TICKS_PER_NS);
      mean_x+=x;mean_y_delta+=phase_samples[i].value-anchor_y;
    end
    mean_x/=real'(PHASE_N);mean_y_delta/=real'(PHASE_N);
    phase_fit_mean=anchor_y+mean_y_delta;xx=0.0;xy=0.0;
    foreach(phase_samples[i])begin
      x=real'(phase_samples[i].ticks-origin)/real'(BW_TICKS_PER_NS)-mean_x;
      y=phase_samples[i].value-anchor_y-mean_y_delta;
      xx+=x*x;xy+=x*y;
    end
    if(!finite_nonnegative_real(xx) || xx<=0.0 ||
       !finite_nonnegative_real(phase_fit_mean))
      core_error("PHASE_FIT",scope_id,$sformatf("window_end_ticks=%0d N=%0d xx=%0.12g mean=%0.12g",
        window_end_ticks,PHASE_N,xx,phase_fit_mean));
    slope=xy/xx;sum_residual=0.0;
    foreach(phase_samples[i])begin
      x=real'(phase_samples[i].ticks-origin)/real'(BW_TICKS_PER_NS)-mean_x;
      residual=phase_samples[i].value-anchor_y-mean_y_delta-slope*x;
      sum_residual+=residual*residual;
    end
    phase_fit_delta=slope*real'(phase_samples[$].ticks-origin)/real'(BW_TICKS_PER_NS);
    phase_fit_rms=$sqrt(sum_residual/real'(PHASE_N));
    if(!finite_nonnegative_real($abs(phase_fit_delta)) ||
       !finite_nonnegative_real(phase_fit_rms))
      core_error("PHASE_FIT",scope_id,$sformatf("window_end_ticks=%0d delta=%0.12g rms=%0.12g",
        window_end_ticks,phase_fit_delta,phase_fit_rms));
    phase_fit_valid=1;
  endtask

  task automatic consume_phase_window();
    phase_sample_t sample,discarded;
    bw_phase_t proposed;
    real steady_enter,steady_exit,rms_enter,rms_exit,trend;
    bit residue;
    if(!PHASE_ENABLE)return;
    phase_window_seq=result_seq;
    residue=retired_activity_valid && retired_episode_id!=episode_id &&
      ((WINDOW_BASIS==BW_NS && window_start_ticks<=retired_last_ticks) ||
       (WINDOW_BASIS==BW_CYCLE && window_start_cycle<=retired_last_cycle));
    phase_eligible=episode_active && window_full && bytes_complete && denominator_valid && !residue;
    if(!phase_eligible)begin break_phase_evidence(window_end_ticks);return;end
    phase_evidence_continuous=1;
    if(phase_samples.size()>=PHASE_N)discarded=phase_samples.pop_front();
    sample.ticks=window_end_ticks;sample.basis_position=(WINDOW_BASIS==BW_NS) ?
      window_end_ticks : window_end_cycle;sample.value=bandwidth_gbps;
    check_queue_growth(phase_samples.size(),scope_id);phase_samples.push_back(sample);
    phase_evidence_count=phase_samples.size();
    phase_evidence_span=sample.basis_position-phase_samples[0].basis_position;
    phase_evidence_sufficient=(phase_evidence_count==PHASE_N) &&
      phase_evidence_span>=((WINDOW_BASIS==BW_NS) ? ns_to_ticks(PHASE_MIN_SPAN,scope_id) : PHASE_MIN_SPAN);
    phase_fit_valid=0;
    if(!phase_evidence_sufficient)return;
    fit_phase_samples();
    steady_enter=PHASE_STEADY_ENTER_ABS+PHASE_STEADY_ENTER_REL*phase_fit_mean;
    steady_exit=PHASE_STEADY_EXIT_ABS+PHASE_STEADY_EXIT_REL*phase_fit_mean;
    rms_enter=PHASE_RMS_ENTER_ABS+PHASE_RMS_ENTER_REL*phase_fit_mean;
    rms_exit=PHASE_RMS_EXIT_ABS+PHASE_RMS_EXIT_REL*phase_fit_mean;
    trend=PHASE_TREND_ABS+PHASE_TREND_REL*phase_fit_mean;
    if(!finite_nonnegative_real(steady_enter) || !finite_nonnegative_real(steady_exit) ||
       !finite_nonnegative_real(rms_enter) || !finite_nonnegative_real(rms_exit) ||
       !finite_nonnegative_real(trend))core_error("PHASE_FIT",scope_id,
         $sformatf("window_end_ticks=%0d mean=%0.12g steady_enter=%0.12g steady_exit=%0.12g rms_enter=%0.12g rms_exit=%0.12g trend=%0.12g",
           window_end_ticks,phase_fit_mean,steady_enter,steady_exit,rms_enter,rms_exit,trend));
    if(phase_current==BW_PHASE_STEADY && $abs(phase_fit_delta)<=steady_exit && phase_fit_rms<=rms_exit)
      proposed=BW_PHASE_STEADY;
    else if($abs(phase_fit_delta)<=steady_enter && phase_fit_rms<=rms_enter)proposed=BW_PHASE_STEADY;
    else if(phase_fit_delta>=trend && phase_fit_rms<=rms_enter)proposed=BW_PHASE_RAMP;
    else if(phase_fit_delta<=-trend && phase_fit_rms<=rms_enter)proposed=BW_PHASE_FALL;
    else proposed=BW_PHASE_UNDETERMINED;
    if(proposed==phase_current)begin
      phase_candidate=BW_PHASE_UNDETERMINED;phase_candidate_count=0;
      return;
    end
    if(phase_candidate_count==0 || proposed!=phase_candidate)begin
      phase_candidate=proposed;phase_candidate_count=1;phase_candidate_ticks=window_end_ticks;
      phase_candidate_total_bytes=total_bytes;phase_candidate_total_events=total_events;
      candidate_unknown_records=raw_unknown_records;candidate_unknown_ticks=unknown_ticks_at(window_end_ticks);
      candidate_unknown_event_records=raw_unknown_event_records;candidate_reset_records=raw_reset_records;
    end else phase_candidate_count=checked_add(phase_candidate_count,1,scope_id);
    if(phase_candidate_count<PHASE_K)return;
    close_phase(phase_candidate_ticks,phase_candidate_total_bytes,phase_candidate_total_events,1,BW_PHASE_CHANGE,
      candidate_unknown_records,candidate_unknown_ticks,candidate_unknown_event_records,candidate_reset_records);
    phase_current=proposed;phase_start_ticks=phase_candidate_ticks;phase_confirmation_ticks=window_end_ticks;
    phase_start_total_bytes=phase_candidate_total_bytes;phase_start_total_events=phase_candidate_total_events;
    phase_start_unknown_records=candidate_unknown_records;phase_start_unknown_ticks=candidate_unknown_ticks;
    phase_start_unknown_event_records=candidate_unknown_event_records;phase_start_reset_records=candidate_reset_records;
    phase_confirmation_delta=phase_fit_delta;phase_confirmation_rms=phase_fit_rms;
    if(proposed!=BW_PHASE_UNDETERMINED)begin
      phase_id=checked_add(phase_id,1,scope_id);phase_active=1;
    end
    phase_candidate_count=0;phase_candidate=BW_PHASE_UNDETERMINED;
    flush_safe_phases();
  endtask

  function automatic bw_u64_t silence_deadline_ticks();
    return checked_add(silence_start_ticks,ns_to_ticks(SILENCE_THRESHOLD,scope_id),scope_id);
  endfunction

  task automatic update_episode_duration();
    episode_duration_valid=episode_first_known && episode_last_known && episode_tail_known &&
                           episode_tail_ticks>episode_first_ticks;
    episode_duration_ticks=episode_duration_valid ? episode_tail_ticks-episode_first_ticks : 0;
  endtask

  function automatic bit unknown_episode_control();
    foreach (active_quality[key])
      if ($isunknown(active_quality[key].reset_n)) return 1;
    return 0;
  endfunction

  task automatic interrupt_silence();
    silence_active=0; observation_gap_active=1;
    if (episode_active) begin
      episode_bytes_complete=0; episode_events_complete=0; episode_last_known=0;
      update_episode_duration();
    end else pre_episode_gap=1;
  endtask

  task automatic start_silence(bw_u64_t at_ticks, bw_u64_t at_cycle);
    if (!silence_active) begin
      silence_active=1; silence_start_ticks=at_ticks; silence_start_cycle=at_cycle;
      // The unknown-time prefix is constant throughout known quiet. Original
      // Q may be completed after a delayed control and later frame are drained;
      // retain its exact prefix rather than querying a past publication cursor.
      silence_unknown_ticks=unknown_ticks_at(at_ticks);
    end
  endtask

  task automatic update_episode_reset_coverage();
    if (!EPISODE_ENABLE || !episode_active || !episode_tail_known) return;
    foreach (episode_quality_intervals[i]) begin
      if (episode_quality_intervals[i].known_reset && episode_tail_known &&
          episode_quality_intervals[i].start_ticks<episode_tail_ticks &&
          episode_quality_intervals[i].end_ticks>episode_first_ticks)
        episode_member_reset_coverage=1;
    end
    foreach (active_quality[key]) begin
      if (active_quality[key].reset_n === 1'b0 && episode_tail_known &&
          active_quality[key].start_ticks<episode_tail_ticks)
        episode_member_reset_coverage=1;
    end
  endtask

  task automatic finish_episode(bw_episode_status_t status, bw_u64_t confirmation);
    if (!EPISODE_ENABLE || !episode_active || core_failure_seen) return;
    update_episode_duration();
    update_episode_reset_coverage();
    finish_episode_phases(status,confirmation);
    if(core_failure_seen)return;
    retired_activity_valid=1;retired_episode_id=episode_id;
    retired_last_ticks=episode_last_ticks;retired_last_cycle=episode_last_cycle;
    episode_active=0; episode_status=status; episode_confirmation_ticks=confirmation;
    silence_active=0;
    episode_e2e_valid=(status==BW_EPISODE_COMPLETE && episode_duration_valid && episode_bytes_complete);
    episode_e2e_gbps=episode_e2e_valid ?
      real'(episode_bytes)*real'(BW_TICKS_PER_NS)/real'(episode_duration_ticks) : 0.0;
    episode_result_seq=checked_add(episode_result_seq,1,scope_id);
    if (core_failure_seen) return;
    episode_result.scope_kind=scope_kind;
    episode_result.stats_epoch=stats_epoch; episode_result.result_seq=episode_result_seq;
    episode_result.episode_id=episode_id; episode_result.status=status;
    episode_result.first_ticks=episode_first_ticks; episode_result.last_ticks=episode_last_ticks;
    episode_result.tail_ticks=episode_tail_ticks; episode_result.confirmation_ticks=confirmation;
    episode_result.first_cycle=episode_first_cycle; episode_result.last_cycle=episode_last_cycle;
    episode_result.tail_cycle=episode_tail_cycle; episode_result.byte_count=episode_bytes;
    episode_result.event_count=episode_events; episode_result.duration_ticks=episode_duration_ticks;
    episode_result.start_total_bytes=episode_start_total_bytes;
    episode_result.end_total_bytes=episode_end_total_bytes;
    episode_result.start_total_events=episode_start_total_events;
    episode_result.end_total_events=episode_end_total_events;
    episode_result.first_known=episode_first_known; episode_result.last_known=episode_last_known;
    episode_result.tail_known=episode_tail_known; episode_result.bytes_complete=episode_bytes_complete;
    episode_result.events_complete=episode_events_complete;
    episode_result.member_reset_coverage=episode_member_reset_coverage;
    episode_result.duration_valid=episode_duration_valid; episode_result.e2e_valid=episode_e2e_valid;
    episode_result.e2e_gbps=episode_e2e_gbps;
    episode_result.variation=final_variation(episode_variation,episode_duration_valid,
      status==BW_EPISODE_RESET_INTERRUPTED ? BW_METRIC_RESET :
      (status==BW_EPISODE_TRUNCATED ? BW_METRIC_TRUNCATED : BW_METRIC_OK));
    episode_result.last_steady_found=last_steady_found;
    episode_result.last_steady_selection_valid=(status==BW_EPISODE_COMPLETE && episode_duration_valid && last_steady_found);
    episode_result.last_steady_reason=status==BW_EPISODE_RESET_INTERRUPTED ? BW_METRIC_RESET :
      (status==BW_EPISODE_TRUNCATED ? BW_METRIC_TRUNCATED :
       (!episode_duration_valid ? BW_METRIC_BOUNDARY_UNKNOWN :
        (!last_steady_found ? BW_METRIC_NO_STEADY : BW_METRIC_OK)));
    episode_result.last_steady=last_steady;
    if(core_failure_seen)return;
    if (status==BW_EPISODE_RESET_INTERRUPTED) episode_result.reason=BW_EPISODE_RESET;
    else if (status==BW_EPISODE_TRUNCATED) episode_result.reason=BW_EPISODE_OBSERVATION_END;
    else if (!episode_first_known) episode_result.reason=BW_EPISODE_FIRST_UNKNOWN;
    else if (!episode_last_known) episode_result.reason=BW_EPISODE_LAST_UNKNOWN;
    else if (!episode_tail_known) episode_result.reason=BW_EPISODE_TAIL_UNKNOWN;
    else if (!episode_bytes_complete) episode_result.reason=BW_EPISODE_BYTES_UNKNOWN;
    else if (!episode_duration_valid) episode_result.reason=BW_EPISODE_DURATION_UNKNOWN;
    else episode_result.reason=BW_EPISODE_REASON_NONE;
    emit_episode_result(scope_id,episode_result);
    episode_pending_samples.delete();phase_pending_samples.delete();
    pre_episode_gap=0; observation_gap_active=0; gap_waits_for_edge=0;
    pending_sample_reset_coverage=0; episode_quality_intervals.delete();
  endtask

  task automatic capture_episode_edge(bw_record_t incoming);
    if (!EPISODE_ENABLE) return;
    gap_waits_for_edge=0;
    if (!episode_active || episode_tail_known) return;
    if (incoming.edge_index>episode_last_cycle) begin
      episode_tail_ticks=incoming.timestamp_ticks; episode_tail_cycle=incoming.edge_index;
      episode_tail_known=1;
      episode_end_total_bytes=total_bytes; episode_end_total_events=total_events;
      episode_end_unknown_records=raw_unknown_records;episode_end_unknown_ticks=unknown_ticks_at(incoming.timestamp_ticks);
      episode_end_unknown_event_records=raw_unknown_event_records;episode_end_reset_records=raw_reset_records;
      update_episode_duration();
      update_episode_reset_coverage();
      if (!observation_gap_active && !unknown_episode_control())
        start_silence(incoming.timestamp_ticks,incoming.edge_index);
    end
  endtask

  task automatic advance_episode_time(bw_u64_t at_ticks, bw_u64_t at_cycle, bit is_edge);
    bit reached;
    bw_u64_t confirmation, safe_ticks;
    if (!EPISODE_ENABLE || !silence_active || current_reset_n === 1'b0) return;
    reached=0; confirmation=at_ticks;
    safe_ticks=(at_ticks<progress_watermark_ticks) ? at_ticks : progress_watermark_ticks;
    if (WINDOW_BASIS==BW_NS && safe_ticks>=silence_deadline_ticks()) begin
      reached=1; confirmation=silence_deadline_ticks();
    end else if (WINDOW_BASIS==BW_CYCLE && is_edge &&
                 at_cycle>=checked_add(silence_start_cycle,SILENCE_THRESHOLD,scope_id)) reached=1;
    if (reached) begin
      if (episode_active) finish_episode(BW_EPISODE_COMPLETE,confirmation);
      else begin pre_episode_gap=0; silence_active=0; end
    end
  endtask

  task automatic account_episode_frame(bw_record_t incoming);
    if (!EPISODE_ENABLE) return;
    if (incoming.event_inc==0) begin
      if (!incoming.events_complete || unknown_episode_control()) begin
        interrupt_silence();
        if (!incoming.events_complete) gap_waits_for_edge=1;
      end else begin
        observation_gap_active=0;
        if (episode_active) begin
          episode_bytes_complete &= incoming.bytes_complete;
          pending_sample_reset_coverage |= (incoming.reset_points!=0);
          if (episode_tail_known) start_silence(incoming.timestamp_ticks,incoming.edge_index);
        end else if (pre_episode_gap) start_silence(incoming.timestamp_ticks,incoming.edge_index);
      end
      return;
    end
    if (!episode_active) begin
      begin_phase_episode();
      episode_id=checked_add(episode_id,1,scope_id);
      episode_active=1; episode_status=BW_EPISODE_ACTIVE;
      episode_first_ticks=incoming.timestamp_ticks; episode_first_cycle=incoming.edge_index;
      episode_first_known=!pre_episode_gap; episode_bytes=0; episode_events=0;
      episode_bytes_complete=!pre_episode_gap; episode_events_complete=!pre_episode_gap;
      episode_member_reset_coverage=0; pending_sample_reset_coverage=0;
      episode_start_total_bytes=total_bytes; episode_start_total_events=total_events;
      episode_end_total_bytes=0; episode_end_total_events=0;
      pre_episode_gap=0; episode_quality_intervals.delete();
    end
    episode_last_ticks=incoming.timestamp_ticks; episode_last_cycle=incoming.edge_index;
    episode_last_known=1; episode_tail_known=0; episode_tail_ticks=0; episode_tail_cycle=0;
    episode_end_total_bytes=0; episode_end_total_events=0;
    episode_duration_valid=0; episode_duration_ticks=0;
    episode_e2e_valid=0; episode_e2e_gbps=0.0; episode_confirmation_ticks=0;
    episode_bytes=checked_add(episode_bytes,incoming.byte_inc,scope_id);
    episode_events=checked_add(episode_events,incoming.event_inc,scope_id);
    episode_bytes_complete &= incoming.bytes_complete;
    episode_events_complete &= incoming.events_complete;
    episode_member_reset_coverage |= pending_sample_reset_coverage || (incoming.reset_points!=0);
    pending_sample_reset_coverage=0;
    observation_gap_active=!incoming.events_complete || unknown_episode_control();
    gap_waits_for_edge=observation_gap_active;
    if (observation_gap_active) begin episode_bytes_complete=0; episode_events_complete=0; end
    silence_active=0;
  endtask

  task automatic episode_control_changed(bw_u64_t at_ticks);
    if (!EPISODE_ENABLE || current_reset_n === 1'b0) return;
    update_episode_reset_coverage();
    if (unknown_episode_control()) interrupt_silence();
    else if (observation_gap_active && !gap_waits_for_edge) begin
      observation_gap_active=0;
      if (WINDOW_BASIS==BW_NS && ((episode_active && episode_tail_known) ||
          (!episode_active && pre_episode_gap))) start_silence(at_ticks,last_edge_index);
    end
  endtask

  task automatic reschedule_episode_timer();
    bit valid_deadline;
    bw_u64_t deadline;
    valid_deadline=EPISODE_ENABLE && WINDOW_BASIS==BW_NS &&
                   (episode_active || pre_episode_gap) && silence_active;
    deadline=valid_deadline ? silence_deadline_ticks() : 0;
    if (valid_deadline!=scheduled_episode_deadline_valid || deadline!=scheduled_episode_deadline) begin
      scheduled_episode_deadline_valid=valid_deadline; scheduled_episode_deadline=deadline;
      timer_schedule_seq=checked_add(timer_schedule_seq,1,scope_id);
    end
  endtask

  task automatic update_quality(int key, logic reset_level, bw_u64_t at_ticks);
    quality_interval_t interval;
    active_quality_t active;
    if (active_quality.exists(key)) begin
      active=active_quality[key];
      if (active.reset_n === reset_level) return;
      if (at_ticks > active.start_ticks) begin
        interval.start_ticks=active.start_ticks; interval.end_ticks=at_ticks;
        interval.unknown_reset=$isunknown(active.reset_n);
        interval.known_reset=(active.reset_n === 1'b0);
        check_queue_growth(quality_intervals.size(),scope_id);
        quality_intervals.push_back(interval);
        if (EPISODE_ENABLE && episode_active && interval.known_reset) begin
          check_queue_growth(episode_quality_intervals.size(),scope_id);
          episode_quality_intervals.push_back(interval);
        end
      end
      active_quality.delete(key);
    end
    if (reset_level !== 1'b1) begin
      active.start_ticks=at_ticks; active.reset_n=reset_level;
      active_quality[key]=active;
    end
  endtask

  task automatic window_control_quality(bw_u64_t left, bw_u64_t right);
    int i;
    quality_interval_t interval;
    i=0;
    while (i<quality_intervals.size()) begin
      interval=quality_intervals[i];
      if (interval.end_ticks<=left) begin
        quality_intervals.delete(i);
        continue;
      end
      if (interval.start_ticks<right && interval.end_ticks>left) begin
        if (interval.unknown_reset) begin bytes_complete=0; events_complete=0; end
        if (interval.known_reset) member_reset_coverage=1;
      end
      i++;
    end
    foreach (active_quality[key]) begin
      if (active_quality[key].start_ticks<right) begin
        if ($isunknown(active_quality[key].reset_n)) begin bytes_complete=0; events_complete=0; end
        if (active_quality[key].reset_n === 1'b0) member_reset_coverage=1;
      end
    end
  endtask

  task automatic initialize_state();
    if (!initialized) begin
      next_update_ticks = checked_add(stats_start_ticks,
                          ns_to_ticks(UPDATE_STRIDE,scope_id),scope_id);
      initialized = 1;
    end
  endtask

  task automatic publish_window(bw_u64_t at_ticks, bw_u64_t at_cycle = 0);
    bw_record_t expired;
    bw_u64_t width_ticks, left, left_cycle;
    if (WINDOW_BASIS == BW_NS) begin
      width_ticks = ns_to_ticks(WINDOW_WIDTH,scope_id);
      left = (at_ticks-stats_start_ticks >= width_ticks) ? at_ticks-width_ticks
                                                       : stats_start_ticks;
      window_full=(at_ticks-stats_start_ticks>=width_ticks);
    end else begin
      left_cycle = (at_cycle-cycle_origin >= WINDOW_WIDTH) ? at_cycle-WINDOW_WIDTH
                                                         : cycle_origin;
      left=cycle_boundary_ticks[0];
      window_start_cycle=left_cycle; window_end_cycle=at_cycle;
      coverage_cycles=at_cycle-left_cycle;
      window_full=(at_cycle-cycle_origin>=WINDOW_WIDTH);
    end
    advance_raw_quality(at_ticks);
    // Rolling exact totals avoid an O(window-history) scan on each update.
    while (history.size() != 0 && ((WINDOW_BASIS == BW_NS && history[0].timestamp_ticks < left) ||
           (WINDOW_BASIS == BW_CYCLE && history[0].edge_index < left_cycle))) begin
      expired=history.pop_front();
      retained_bytes -= expired.byte_inc;
      retained_events -= expired.event_inc;
      if (!expired.bytes_complete) unknown_bytes--;
      if (!expired.events_complete) unknown_events--;
      if (expired.reset_points != 0) reset_entries--;
    end
    window_start_ticks=left; window_end_ticks=at_ticks;
    coverage_ticks=at_ticks-left;
    window_bytes=retained_bytes; window_events=retained_events;
    bytes_complete=(unknown_bytes==0); events_complete=(unknown_events==0);
    member_reset_coverage=(reset_entries!=0);
    window_control_quality(left,at_ticks);
    denominator_valid=(coverage_ticks!=0);
    window_warmup=!window_full;
    window_valid=window_full && bytes_complete && denominator_valid;
    if (denominator_valid)
      bandwidth_gbps=real'(window_bytes)*real'(BW_TICKS_PER_NS)/real'(coverage_ticks);
    else bandwidth_gbps=0.0;
    if (WINDOW_BASIS == BW_CYCLE && coverage_cycles != 0)
      bytes_per_cycle=real'(window_bytes)/real'(coverage_cycles);
    result_seq=checked_add(result_seq,1,scope_id);
    retain_variation_sample();
    consume_phase_window();
    flush_safe_phases();
  endtask

  task automatic clear_statistics(bw_u64_t at_ticks);
    advance_raw_quality(at_ticks);
    if (EPISODE_ENABLE && episode_active && progress_watermark_ticks<at_ticks)
      interrupt_silence();
    finish_episode(BW_EPISODE_RESET_INTERRUPTED,at_ticks);
    retired_activity_valid=0;
    begin_phase_episode();
    silence_active=0;
    pre_episode_gap=0; observation_gap_active=0; gap_waits_for_edge=0;
    pending_sample_reset_coverage=0; episode_quality_intervals.delete();
    episode_status=BW_EPISODE_NONE;
    episode_first_ticks=0; episode_last_ticks=0; episode_tail_ticks=0; episode_confirmation_ticks=0;
    episode_first_cycle=0; episode_last_cycle=0; episode_tail_cycle=0;
    episode_bytes=0; episode_events=0; episode_duration_ticks=0;
    episode_first_known=0; episode_last_known=0; episode_tail_known=0;
    episode_bytes_complete=1; episode_events_complete=1; episode_member_reset_coverage=0;
    episode_duration_valid=0; episode_e2e_valid=0; episode_e2e_gbps=0.0;
    stats_epoch=checked_add(stats_epoch,1,scope_id);
    stats_start_ticks=at_ticks;
    history.delete(); cycle_boundary_ticks.delete();
    quality_intervals.delete(); active_quality.delete(-1);
    retained_bytes=0; retained_events=0;
    unknown_bytes=0; unknown_events=0; reset_entries=0;
    total_bytes=0; total_events=0;
    raw_reset_records=0;
    raw_unknown_records=0;raw_unknown_event_records=0;raw_unknown_ticks=0;raw_quality_ticks=at_ticks;
    window_start_ticks=0; window_end_ticks=0;
    window_start_cycle=0; window_end_cycle=0;
    coverage_ticks=0; coverage_cycles=0;
    window_bytes=0; window_events=0;
    bandwidth_gbps=0.0; bytes_per_cycle=0.0;
    window_warmup=1; window_full=0;
    bytes_complete=1; events_complete=1;
    denominator_valid=0; window_valid=0; member_reset_coverage=0;
    initialized=0; cycle_initialized=0;
    // Transport positions, acceptance receipts and result sequence never rewind.
    timer_schedule_seq=checked_add(timer_schedule_seq,1,scope_id);
  endtask

  task automatic enqueue_reset();
    reset_action_t action;
    if (reset_enqueued && observed_reset_n === stats_reset_n) return;
    check_monitor_time($time,scope_id);
    observed_reset_n=stats_reset_n;
    reset_enqueued=1;
    action.timestamp_ticks=$time; action.reset_n=stats_reset_n;
    check_queue_growth(pending_resets.size(),scope_id);
    pending_resets.push_back(action);
    requested_actions=checked_add(requested_actions,1,scope_id);
  endtask

  task automatic apply_reset(reset_action_t action);
    if (reset_applied && action.reset_n !== 1'b0 && current_reset_n !== 1'b0) begin
      if (WINDOW_BASIS==BW_NS) publish_due(action.timestamp_ticks);
      advance_episode_time(action.timestamp_ticks,last_edge_index,0);
    end
    if (action.reset_n === 1'b0 && (!reset_applied || current_reset_n !== 1'b0)) begin
      clear_statistics(action.timestamp_ticks);
      last_assert_ticks=action.timestamp_ticks;
      assertion_observed=1;
    end else if (reset_applied && current_reset_n === 1'b0 && action.reset_n !== 1'b0) begin
      stats_start_ticks=action.timestamp_ticks;
      initialized=0;
      initialize_state();
      timer_schedule_seq=checked_add(timer_schedule_seq,1,scope_id);
    end else if (!reset_applied) begin
      stats_start_ticks=measurement_start_ticks;
      initialize_state();
    end
    advance_raw_quality(action.timestamp_ticks);
    current_reset_n=action.reset_n;
    reset_applied=1;
    update_quality(-1,action.reset_n,action.timestamp_ticks);
    episode_control_changed(action.timestamp_ticks);
  endtask

  task automatic apply_member_control(bw_control_t incoming);
    int key;
    bw_u64_t expected_seq;
    key=int'(incoming.point_handle);
    check_monitor_time(incoming.timestamp_ticks,scope_id);
    if (incoming.timestamp_ticks>$time)
      core_error("CONTROL_TIME",scope_id,"control timestamp is in the future");
    if (incoming.point_handle>=expected_point_count)
      core_error("POINT_REFERENCE",scope_id,
        $sformatf("control point_handle=%0d registered_points=%0d",incoming.point_handle,expected_point_count));
    expected_seq=member_control_sequences.exists(key) ?
                 checked_add(member_control_sequences[key],1,scope_id) : 1;
    if (incoming.control_seq!=expected_seq)
      core_error("CONTROL_SEQUENCE",scope_id,
        $sformatf("point_handle=%0d expected=%0d received=%0d",key,expected_seq,incoming.control_seq));
    if (member_control_times.exists(key) && incoming.timestamp_ticks<member_control_times[key])
      core_error("CONTROL_TIME",scope_id,$sformatf("point_handle=%0d time_ticks=%0d",key,incoming.timestamp_ticks));
    member_control_sequences[key]=incoming.control_seq;
    member_control_times[key]=incoming.timestamp_ticks;
    if (WINDOW_BASIS==BW_NS && current_reset_n !== 1'b0) publish_due(incoming.timestamp_ticks);
    advance_episode_time(incoming.timestamp_ticks,last_edge_index,0);
    if(incoming.timestamp_ticks>=stats_start_ticks)advance_raw_quality(incoming.timestamp_ticks);
    update_quality(key,incoming.reset_n,incoming.timestamp_ticks);
    if((incoming.timestamp_ticks<stats_start_ticks ||
        (incoming.timestamp_ticks==stats_start_ticks && !$isunknown(incoming.reset_n))) &&
        !episode_active && current_reset_n!==1'b0)begin
      // A pre-epoch notification refreshes member state, not lost observation
      // in the new epoch. The progress barrier prevents newer raw activity
      // from being accepted before these historical controls catch up.
      if(unknown_episode_control())interrupt_silence();
      else if(raw_unknown_ticks==0 && raw_unknown_records==0)begin
        pre_episode_gap=0;observation_gap_active=0;gap_waits_for_edge=0;silence_active=0;
      end else begin
        // An independent own-control gap in this epoch survives historical
        // member recovery. Resume quiet from its actual latest observation,
        // never from the historical member time or the delivery time.
        observation_gap_active=0;gap_waits_for_edge=0;
        if(pre_episode_gap && WINDOW_BASIS==BW_NS)start_silence(raw_quality_ticks,last_edge_index);
      end
    end else episode_control_changed(incoming.timestamp_ticks);
    accepted_control_count=checked_add(accepted_control_count,1,scope_id);
  endtask

  task automatic publish_due(bw_u64_t through_ticks);
    bw_u64_t safe_ticks;
    safe_ticks=(through_ticks<progress_watermark_ticks) ? through_ticks : progress_watermark_ticks;
    initialize_state();
    while (next_update_ticks <= safe_ticks) begin
      publish_window(next_update_ticks);
      next_update_ticks=checked_add(next_update_ticks,ns_to_ticks(UPDATE_STRIDE,scope_id),scope_id);
    end
  endtask

  // One run-to-completion entry owns state. A frame arriving before the timer
  // publishes all due [left,T) results before accounting T's event; a timer
  // arriving first advances the same schedule, so either order gives one result.
  task automatic dispatch(bit is_frame, bw_record_t incoming, bw_u64_t now_ticks);
    bw_u64_t left_cycle, discarded_boundary;
    if (!monitor_ready) return;
    if (is_frame) begin
      if (incoming.record_seq != checked_add(last_record_seq,1,scope_id))
        core_error("RECORD_SEQUENCE",scope_id,
                   $sformatf("expected=%0d received=%0d",last_record_seq+1,incoming.record_seq));
      if (last_record_seq!=0 && incoming.timestamp_ticks<=last_frame_ticks)
        core_error("RECORD_TIME",scope_id,"sampling timestamps must strictly increase");
      if (last_record_seq!=0 && incoming.edge_index!=checked_add(last_edge_index,1,scope_id))
        core_error("EDGE_SEQUENCE",scope_id,
                   $sformatf("expected=%0d received=%0d",last_edge_index+1,incoming.edge_index));
      last_record_seq=incoming.record_seq; last_frame_ticks=incoming.timestamp_ticks;
      last_edge_index=incoming.edge_index;
      if (current_reset_n === 1'b0 || incoming.timestamp_ticks < stats_start_ticks ||
          (assertion_observed && incoming.timestamp_ticks==last_assert_ticks)) begin
        accepted_record_seq=incoming.record_seq;
        return;
      end
      capture_episode_edge(incoming);
      if (WINDOW_BASIS == BW_CYCLE) begin
        if (!cycle_initialized) begin
          cycle_origin=incoming.edge_index;
          boundary_first_cycle=cycle_origin;
          next_update_cycle=checked_add(cycle_origin,UPDATE_STRIDE,scope_id);
          cycle_initialized=1;
        end
        check_queue_growth(cycle_boundary_ticks.size(),scope_id);
        cycle_boundary_ticks.push_back(incoming.timestamp_ticks);
        left_cycle=(incoming.edge_index-cycle_origin>=WINDOW_WIDTH) ?
                    incoming.edge_index-WINDOW_WIDTH : cycle_origin;
        while (boundary_first_cycle<left_cycle) begin
          discarded_boundary=cycle_boundary_ticks.pop_front();
          boundary_first_cycle=checked_add(boundary_first_cycle,1,scope_id);
        end
        if (incoming.edge_index == next_update_cycle) begin
          publish_window(now_ticks,incoming.edge_index);
          next_update_cycle=checked_add(next_update_cycle,UPDATE_STRIDE,scope_id);
        end
      end
    end
    if (current_reset_n === 1'b0) return;
    if (WINDOW_BASIS == BW_NS) publish_due(now_ticks);
    advance_episode_time(now_ticks,is_frame ? incoming.edge_index : last_edge_index,is_frame);
    if (!is_frame) return;
    advance_raw_quality(now_ticks);
    account_episode_frame(incoming);
    flush_safe_phases();
    if(!incoming.bytes_complete || !incoming.events_complete)
      raw_unknown_records=checked_add(raw_unknown_records,1,scope_id);
    if(!incoming.events_complete)raw_unknown_event_records=checked_add(raw_unknown_event_records,1,scope_id);
    if(incoming.reset_points!=0)raw_reset_records=checked_add(raw_reset_records,1,scope_id);
    total_bytes=checked_add(total_bytes,incoming.byte_inc,scope_id);
    total_events=checked_add(total_events,incoming.event_inc,scope_id);
    retained_bytes=checked_add(retained_bytes,incoming.byte_inc,scope_id);
    retained_events=checked_add(retained_events,incoming.event_inc,scope_id);
    if (!incoming.bytes_complete) unknown_bytes=checked_add(unknown_bytes,1,scope_id);
    if (!incoming.events_complete) unknown_events=checked_add(unknown_events,1,scope_id);
    if (incoming.reset_points!=0) reset_entries=checked_add(reset_entries,1,scope_id);
    if (incoming.byte_inc!=0 || incoming.event_inc!=0 || !incoming.bytes_complete ||
        !incoming.events_complete || incoming.reset_points!=0) begin
      check_queue_growth(history.size(),scope_id);
      history.push_back(incoming);
    end
    accepted_record_seq=incoming.record_seq;
  endtask

  always @(record_toggle) begin
    if (monitor_ready && record.record_seq != 0) begin
      if (record.timestamp_ticks>$time)
        core_error("RECORD_TIME",scope_id,"record timestamp is in the future");
      check_queue_growth(pending_frames.size(),scope_id);
      pending_frames.push_back(record);
      requested_actions=checked_add(requested_actions,1,scope_id);
    end
  end
  always @(stats_reset_n) if (monitor_ready) enqueue_reset();
  always @(member_control_toggle) begin
    if (monitor_ready && member_control.control_seq!=0) begin
      check_queue_growth(pending_member_controls.size(),scope_id);
      pending_member_controls.push_back(member_control);
      requested_actions=checked_add(requested_actions,1,scope_id);
    end
  end

  task automatic drain_actions();
    reset_action_t reset_action;
    bw_record_t frame;
    bw_control_t control;
    bw_u64_t timer_tick;
    check_monitor_time($time,scope_id);
    while (consumed_actions != requested_actions) begin
      if (pending_resets.size()!=0) begin
        reset_action=pending_resets.pop_front();
        apply_reset(reset_action);
      end else if (pending_member_controls.size()!=0) begin
        control=pending_member_controls.pop_front();
        apply_member_control(control);
      end else if (pending_frames.size()!=0) begin
        frame=pending_frames.pop_front();
        dispatch(1,frame,frame.timestamp_ticks);
      end else begin
        timer_tick=pending_timers.pop_front();
        dispatch(0,'0,timer_tick);
        timer_receipts=checked_add(timer_receipts,1,scope_id);
      end
      consumed_actions=checked_add(consumed_actions,1,scope_id);
      reschedule_episode_timer();
    end
  endtask

  bw_stats_core_scheduler scheduler();

  initial begin
    bw_u64_t observed_schedule, due_tick, request_number;
    wait(monitor_ready);
    enqueue_reset();
    wait(reset_applied);
    if (WINDOW_BASIS == BW_NS) begin
      forever begin
        observed_schedule=timer_schedule_seq;
        if (current_reset_n === 1'b0) begin
          wait(timer_schedule_seq != observed_schedule);
        end else begin
          due_tick=next_update_ticks;
          if (scheduled_episode_deadline_valid && scheduled_episode_deadline<due_tick)
            due_tick=scheduled_episode_deadline;
          if (due_tick>progress_watermark_ticks)
            wait(timer_schedule_seq!=observed_schedule || due_tick<=progress_watermark_ticks);
          if ($time < due_tick) begin
            fork : wait_for_timer
              begin #(due_tick-$time); end
              begin wait(timer_schedule_seq != observed_schedule); end
            join_any
            disable wait_for_timer;
          end
          if (timer_schedule_seq == observed_schedule && $time >= due_tick &&
              due_tick<=progress_watermark_ticks) begin
            check_queue_growth(pending_timers.size(),scope_id);
            pending_timers.push_back($time);
            timer_requests=checked_add(timer_requests,1,scope_id);
            request_number=timer_requests;
            requested_actions=checked_add(requested_actions,1,scope_id);
            wait(timer_receipts >= request_number);
          end
        end
      end
    end
  end

  initial begin
    wait(scope_id.len()!=0);
    validate_episode_config(EPISODE_ENABLE,SILENCE_THRESHOLD,WINDOW_BASIS,scope_id);
    validate_phase_config(PHASE_ENABLE,EPISODE_ENABLE,WINDOW_BASIS,PHASE_N,PHASE_MIN_SPAN,PHASE_K,
      PHASE_STEADY_ENTER_ABS,PHASE_STEADY_ENTER_REL,PHASE_STEADY_EXIT_ABS,PHASE_STEADY_EXIT_REL,
      PHASE_RMS_ENTER_ABS,PHASE_RMS_ENTER_REL,PHASE_RMS_EXIT_ABS,PHASE_RMS_EXIT_REL,
      PHASE_TREND_ABS,PHASE_TREND_REL,scope_id);
  end

  final begin
    if (EPISODE_ENABLE && monitor_ready && !core_failure_pending()) begin
      if (monitor_time_supported($time)) begin
        advance_episode_time($time,last_edge_index,0);
        if (episode_active && progress_watermark_ticks<$time) interrupt_silence();
        if (!core_failure_pending()) finish_episode(BW_EPISODE_TRUNCATED,$time);
      end else check_monitor_time($time,scope_id);
    end
  end
endmodule

program bw_stats_core_scheduler;
  timeunit 1fs; timeprecision 1fs;
  initial forever begin
    wait(bw_stats_core.requested_actions != bw_stats_core.consumed_actions);
    bw_stats_core.drain_actions();
  end
endprogram
