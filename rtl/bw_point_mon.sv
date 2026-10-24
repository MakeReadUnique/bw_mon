module bw_point_mon #(
  parameter string POINT_ID = "__BW_AUTO__",
  parameter string CLOCK_CONTEXT = "default",
  parameter bw_mon_pkg::bw_basis_t WINDOW_BASIS = bw_mon_pkg::BW_NS,
  parameter bw_mon_pkg::bw_u64_t WINDOW_WIDTH = 0,
  parameter bw_mon_pkg::bw_u64_t UPDATE_STRIDE = 0,
  parameter logic [63:0] FIXED_BYTES = 64'b0,
  parameter bw_mon_pkg::bw_protocol_t PROTOCOL = bw_mon_pkg::BW_VALID_ONLY,
  parameter bit DYNAMIC_BYTES = 0,
  parameter bit CREDIT_ENABLE = 0,
  parameter logic [63:0] CREDIT_CAPACITY = 64'bx,
  parameter logic [63:0] CREDIT_INITIAL = 64'bx,
  parameter bit CREDIT_INITIAL_KNOWN = 0,
  parameter bw_mon_pkg::bw_credit_return_t CREDIT_RETURN_TIMING = bw_mon_pkg::BW_RETURN_NEXT_CYCLE,
  parameter bit BACKPRESSURE_ENABLE = 0,
  parameter logic [1:0] BACKPRESSURE_BASIS = 2'bxx,
  parameter logic [63:0] BACKPRESSURE_THRESHOLD = 64'bx,
  parameter bit SHORTAGE_ENABLE = 0,
  parameter logic [1:0] SHORTAGE_BASIS = 2'bxx,
  parameter logic [63:0] SHORTAGE_THRESHOLD = 64'bx,
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
  input logic clk,
  input logic reset_n,
  input logic valid = 1'b0,
  input logic ready = 1'b0,
  input logic flitv = 1'b0,
  input logic lcrdv = 1'b0,
  input logic [63:0] size_bytes = 64'bx,
  input logic size_known = 1'b0
);
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  string scope_id, monitor_path;
  bw_scope_t scope_kind = BW_POINT;
  int source_handle;
  int transport_source;
  bw_record_t raw_record;
  bw_control_t raw_control;
  bw_sample_t sampled_view;
  bw_protocol_t protocol = PROTOCOL;
  bit dynamic_bytes = DYNAMIC_BYTES;
  wire sampled_reset_n = sampled_view.reset_n;
  wire sampled_valid = sampled_view.valid;
  wire sampled_ready = sampled_view.ready;
  wire sampled_flitv = sampled_view.flitv;
  wire sampled_lcrdv = sampled_view.lcrdv;
  wire [63:0] sampled_size_bytes = sampled_view.size_bytes;
  wire sampled_size_known = sampled_view.size_known;
  bit credit_supported,credit_enabled,credit_trusted,credit_anomaly;
  bw_credit_state_t credit_state;
  bw_credit_reason_t credit_reason;
  logic [63:0] credit_balance,credit_last_trusted_balance;
  logic [64:0] credit_available_before;
  logic signed [65:0] credit_attempted_balance;
  bit credit_permission_known,credit_shortage_known;
  logic credit_send_permitted,credit_shortage;
  bw_u64_t credit_anomaly_count,credit_result_seq,credit_epoch,credit_update_ticks,credit_record_seq;
  logic [63:0] credit_capacity = CREDIT_CAPACITY;
  logic [63:0] credit_initial = CREDIT_INITIAL;
  bit credit_initial_known = CREDIT_INITIAL_KNOWN;
  bw_credit_return_t credit_return_timing = CREDIT_RETURN_TIMING;
  bw_hint_result_t backpressure_result,shortage_result;
  logic [1:0] backpressure_basis=BACKPRESSURE_BASIS,shortage_basis=SHORTAGE_BASIS;
  logic [63:0] backpressure_threshold=BACKPRESSURE_THRESHOLD,shortage_threshold=SHORTAGE_THRESHOLD;
  wire backpressure_supported=backpressure_result.supported;
  wire backpressure_enabled=backpressure_result.enabled;
  wire backpressure_trusted=backpressure_result.trusted;
  wire backpressure_active=backpressure_result.active;
  wire backpressure_hit=backpressure_result.hit;
  wire backpressure_cycle_anchor_valid=backpressure_result.cycle_anchor_valid;
  bw_hint_end_t backpressure_end_reason;
  assign backpressure_end_reason=backpressure_result.end_reason;
  wire [63:0] backpressure_epoch=backpressure_result.epoch;
  wire [63:0] backpressure_interval_epoch=backpressure_result.interval_epoch;
  wire [63:0] backpressure_interval_id=backpressure_result.interval_id;
  wire [63:0] backpressure_result_seq=backpressure_result.result_seq;
  wire [63:0] backpressure_start_ticks=backpressure_result.start_ticks;
  wire [63:0] backpressure_trigger_ticks=backpressure_result.trigger_ticks;
  wire [63:0] backpressure_end_ticks=backpressure_result.end_ticks;
  wire [63:0] backpressure_observed_through_ticks=backpressure_result.observed_through_ticks;
  wire [63:0] backpressure_update_ticks=backpressure_result.update_ticks;
  wire [63:0] backpressure_duration_ticks=backpressure_result.duration_ticks;
  wire [63:0] backpressure_start_cycle=backpressure_result.start_cycle;
  wire [63:0] backpressure_end_cycle=backpressure_result.end_cycle;
  wire [63:0] backpressure_duration_cycles=backpressure_result.duration_cycles;
  wire [63:0] backpressure_hit_count=backpressure_result.hit_count;
  wire [63:0] backpressure_interval_count=backpressure_result.interval_count;
  wire shortage_supported=shortage_result.supported;
  wire shortage_enabled=shortage_result.enabled;
  wire shortage_trusted=shortage_result.trusted;
  wire shortage_active=shortage_result.active;
  wire shortage_hit=shortage_result.hit;
  wire shortage_cycle_anchor_valid=shortage_result.cycle_anchor_valid;
  bw_hint_end_t shortage_end_reason;
  assign shortage_end_reason=shortage_result.end_reason;
  wire [63:0] shortage_epoch=shortage_result.epoch;
  wire [63:0] shortage_interval_epoch=shortage_result.interval_epoch;
  wire [63:0] shortage_interval_id=shortage_result.interval_id;
  wire [63:0] shortage_result_seq=shortage_result.result_seq;
  wire [63:0] shortage_start_ticks=shortage_result.start_ticks;
  wire [63:0] shortage_trigger_ticks=shortage_result.trigger_ticks;
  wire [63:0] shortage_end_ticks=shortage_result.end_ticks;
  wire [63:0] shortage_observed_through_ticks=shortage_result.observed_through_ticks;
  wire [63:0] shortage_update_ticks=shortage_result.update_ticks;
  wire [63:0] shortage_duration_ticks=shortage_result.duration_ticks;
  wire [63:0] shortage_start_cycle=shortage_result.start_cycle;
  wire [63:0] shortage_end_cycle=shortage_result.end_cycle;
  wire [63:0] shortage_duration_cycles=shortage_result.duration_cycles;
  wire [63:0] shortage_hit_count=shortage_result.hit_count;
  wire [63:0] shortage_interval_count=shortage_result.interval_count;
  bit record_toggle, control_toggle;
  bw_u64_t accepted_record_seq;
  bw_u64_t stats_epoch,result_seq,total_bytes,total_events;
  bw_u64_t window_start_ticks,window_end_ticks,window_start_cycle,window_end_cycle;
  bw_u64_t coverage_ticks,coverage_cycles,window_bytes,window_events;
  real bandwidth_gbps,bytes_per_cycle;
  bit window_warmup,window_full,bytes_complete,events_complete;
  bit denominator_valid,window_valid,member_reset_coverage;
  bit episode_active,episode_first_known,episode_last_known,episode_tail_known;
  bit episode_bytes_complete,episode_events_complete,episode_member_reset_coverage;
  bit episode_duration_valid,episode_e2e_valid;
  bw_episode_status_t episode_status;
  bw_u64_t episode_id,episode_result_seq;
  bw_u64_t episode_first_ticks,episode_last_ticks,episode_tail_ticks,episode_confirmation_ticks;
  bw_u64_t episode_first_cycle,episode_last_cycle,episode_tail_cycle;
  bw_u64_t episode_bytes,episode_events,episode_duration_ticks;
  real episode_e2e_gbps;
  bw_episode_result_t episode_result;
  bw_phase_t phase_current;
  bw_phase_t phase_candidate;
  bit phase_active;
  bit phase_eligible;
  bit phase_evidence_continuous;
  bit phase_evidence_sufficient;
  bit phase_fit_valid;
  bw_u64_t phase_id;
  bw_u64_t phase_result_seq;
  bw_u64_t phase_window_seq;
  bw_u64_t phase_evidence_count;
  bw_u64_t phase_evidence_span;
  bw_u64_t phase_candidate_count;
  bw_u64_t phase_candidate_ticks;
  bw_u64_t phase_candidate_total_bytes;
  bw_u64_t phase_candidate_total_events;
  bw_u64_t phase_start_ticks;
  bw_u64_t phase_confirmation_ticks;
  real phase_fit_mean;
  real phase_fit_delta;
  real phase_fit_rms;
  bw_phase_result_t phase_result;

  // Final immutable metrics are flattened here for ordinary waveform views.
  wire [63:0] phase_duration_ticks=phase_result.duration_ticks;
  wire [63:0] phase_byte_count=phase_result.byte_count;
  wire [63:0] phase_event_count=phase_result.event_count;
  wire phase_duration_valid=phase_result.duration_valid;
  wire phase_bandwidth_valid=phase_result.bandwidth_valid;
  wire phase_member_reset_coverage=phase_result.member_reset_coverage;
  wire phase_bytes_complete=phase_result.bytes_complete;
  wire phase_events_complete=phase_result.events_complete;
  real phase_bandwidth_gbps;
  assign phase_bandwidth_gbps=phase_result.bandwidth_gbps;
  bw_metric_reason_t phase_duration_reason;
  assign phase_duration_reason=phase_result.duration_reason;
  bw_metric_reason_t phase_bandwidth_reason;
  assign phase_bandwidth_reason=phase_result.bandwidth_reason;
  wire episode_last_steady_found=episode_result.last_steady_found;
  wire episode_last_steady_selection_valid=episode_result.last_steady_selection_valid;
  bw_metric_reason_t episode_last_steady_reason;
  assign episode_last_steady_reason=episode_result.last_steady_reason;
  wire [63:0] episode_last_steady_phase_id=episode_result.last_steady.phase_id;
  wire [63:0] episode_last_steady_start_ticks=episode_result.last_steady.start_ticks;
  wire [63:0] episode_last_steady_end_ticks=episode_result.last_steady.end_ticks;
  real episode_last_steady_bandwidth_gbps;
  assign episode_last_steady_bandwidth_gbps=episode_result.last_steady.bandwidth_gbps;
  wire episode_last_steady_bandwidth_valid=episode_result.last_steady.bandwidth_valid;
  wire [63:0] phase_variation_sample_count=phase_result.variation.sample_count;
  wire [63:0] phase_variation_first_sample_ticks=phase_result.variation.first_sample_ticks;
  wire [63:0] phase_variation_last_sample_ticks=phase_result.variation.last_sample_ticks;
  wire [63:0] phase_variation_sample_span_ticks=phase_result.variation.sample_span_ticks;
  wire [63:0] phase_variation_excluded_warmup=phase_result.variation.excluded_warmup;
  wire [63:0] phase_variation_excluded_foreign=phase_result.variation.excluded_foreign;
  wire [63:0] phase_variation_unknown_samples=phase_result.variation.unknown_samples;
  wire [63:0] phase_variation_excluded_denominator=phase_result.variation.excluded_denominator;
  real phase_variation_mean_gbps;
  assign phase_variation_mean_gbps=phase_result.variation.mean_gbps;
  real phase_variation_min_gbps;
  assign phase_variation_min_gbps=phase_result.variation.min_gbps;
  real phase_variation_max_gbps;
  assign phase_variation_max_gbps=phase_result.variation.max_gbps;
  real phase_variation_stddev_gbps;
  assign phase_variation_stddev_gbps=phase_result.variation.stddev_gbps;
  real phase_variation_cv_pct;
  assign phase_variation_cv_pct=phase_result.variation.cv_pct;
  wire phase_variation_interval_known=phase_result.variation.interval_known;
  wire phase_variation_coverage_complete=phase_result.variation.coverage_complete;
  wire phase_variation_minmax_valid=phase_result.variation.minmax_valid;
  wire phase_variation_stddev_valid=phase_result.variation.stddev_valid;
  wire phase_variation_cv_valid=phase_result.variation.cv_valid;
  bw_metric_reason_t phase_variation_minmax_reason;
  assign phase_variation_minmax_reason=phase_result.variation.minmax_reason;
  bw_metric_reason_t phase_variation_stddev_reason;
  assign phase_variation_stddev_reason=phase_result.variation.stddev_reason;
  bw_metric_reason_t phase_variation_cv_reason;
  assign phase_variation_cv_reason=phase_result.variation.cv_reason;
  wire [63:0] episode_variation_sample_count=episode_result.variation.sample_count;
  wire [63:0] episode_variation_first_sample_ticks=episode_result.variation.first_sample_ticks;
  wire [63:0] episode_variation_last_sample_ticks=episode_result.variation.last_sample_ticks;
  wire [63:0] episode_variation_sample_span_ticks=episode_result.variation.sample_span_ticks;
  wire [63:0] episode_variation_excluded_warmup=episode_result.variation.excluded_warmup;
  wire [63:0] episode_variation_excluded_foreign=episode_result.variation.excluded_foreign;
  wire [63:0] episode_variation_unknown_samples=episode_result.variation.unknown_samples;
  wire [63:0] episode_variation_excluded_denominator=episode_result.variation.excluded_denominator;
  real episode_variation_mean_gbps;
  assign episode_variation_mean_gbps=episode_result.variation.mean_gbps;
  real episode_variation_min_gbps;
  assign episode_variation_min_gbps=episode_result.variation.min_gbps;
  real episode_variation_max_gbps;
  assign episode_variation_max_gbps=episode_result.variation.max_gbps;
  real episode_variation_stddev_gbps;
  assign episode_variation_stddev_gbps=episode_result.variation.stddev_gbps;
  real episode_variation_cv_pct;
  assign episode_variation_cv_pct=episode_result.variation.cv_pct;
  wire episode_variation_interval_known=episode_result.variation.interval_known;
  wire episode_variation_coverage_complete=episode_result.variation.coverage_complete;
  wire episode_variation_minmax_valid=episode_result.variation.minmax_valid;
  wire episode_variation_stddev_valid=episode_result.variation.stddev_valid;
  wire episode_variation_cv_valid=episode_result.variation.cv_valid;
  bw_metric_reason_t episode_variation_minmax_reason;
  assign episode_variation_minmax_reason=episode_result.variation.minmax_reason;
  bw_metric_reason_t episode_variation_stddev_reason;
  assign episode_variation_stddev_reason=episode_result.variation.stddev_reason;
  bw_metric_reason_t episode_variation_cv_reason;
  assign episode_variation_cv_reason=episode_result.variation.cv_reason;
  wire [63:0] episode_last_steady_variation_sample_count=episode_result.last_steady.variation.sample_count;
  wire [63:0] episode_last_steady_variation_first_sample_ticks=episode_result.last_steady.variation.first_sample_ticks;
  wire [63:0] episode_last_steady_variation_last_sample_ticks=episode_result.last_steady.variation.last_sample_ticks;
  wire [63:0] episode_last_steady_variation_sample_span_ticks=episode_result.last_steady.variation.sample_span_ticks;
  wire [63:0] episode_last_steady_variation_excluded_warmup=episode_result.last_steady.variation.excluded_warmup;
  wire [63:0] episode_last_steady_variation_excluded_foreign=episode_result.last_steady.variation.excluded_foreign;
  wire [63:0] episode_last_steady_variation_unknown_samples=episode_result.last_steady.variation.unknown_samples;
  wire [63:0] episode_last_steady_variation_excluded_denominator=episode_result.last_steady.variation.excluded_denominator;
  real episode_last_steady_variation_mean_gbps;
  assign episode_last_steady_variation_mean_gbps=episode_result.last_steady.variation.mean_gbps;
  real episode_last_steady_variation_min_gbps;
  assign episode_last_steady_variation_min_gbps=episode_result.last_steady.variation.min_gbps;
  real episode_last_steady_variation_max_gbps;
  assign episode_last_steady_variation_max_gbps=episode_result.last_steady.variation.max_gbps;
  real episode_last_steady_variation_stddev_gbps;
  assign episode_last_steady_variation_stddev_gbps=episode_result.last_steady.variation.stddev_gbps;
  real episode_last_steady_variation_cv_pct;
  assign episode_last_steady_variation_cv_pct=episode_result.last_steady.variation.cv_pct;
  wire episode_last_steady_variation_interval_known=episode_result.last_steady.variation.interval_known;
  wire episode_last_steady_variation_coverage_complete=episode_result.last_steady.variation.coverage_complete;
  wire episode_last_steady_variation_minmax_valid=episode_result.last_steady.variation.minmax_valid;
  wire episode_last_steady_variation_stddev_valid=episode_result.last_steady.variation.stddev_valid;
  wire episode_last_steady_variation_cv_valid=episode_result.last_steady.variation.cv_valid;
  bw_metric_reason_t episode_last_steady_variation_minmax_reason;
  assign episode_last_steady_variation_minmax_reason=episode_result.last_steady.variation.minmax_reason;
  bw_metric_reason_t episode_last_steady_variation_stddev_reason;
  assign episode_last_steady_variation_stddev_reason=episode_result.last_steady.variation.stddev_reason;
  bw_metric_reason_t episode_last_steady_variation_cv_reason;
  assign episode_last_steady_variation_cv_reason=episode_result.last_steady.variation.cv_reason;

  // Unnamed block deliberately preserves exactly the public instance scope.
  initial begin
    monitor_path=$sformatf("%m");
    scope_id=(POINT_ID=="__BW_AUTO__") ? monitor_path : POINT_ID;
    validate_point_protocol(PROTOCOL,DYNAMIC_BYTES,FIXED_BYTES,scope_id);
    validate_credit_config(PROTOCOL,CREDIT_ENABLE,CREDIT_CAPACITY,CREDIT_INITIAL,
                           CREDIT_INITIAL_KNOWN,CREDIT_RETURN_TIMING,scope_id);
    validate_hint_config(PROTOCOL==BW_VALID_READY,BACKPRESSURE_ENABLE,BACKPRESSURE_BASIS,
                         BACKPRESSURE_THRESHOLD,scope_id,"backpressure");
    validate_hint_config(PROTOCOL==BW_CREDIT,SHORTAGE_ENABLE,SHORTAGE_BASIS,
                         SHORTAGE_THRESHOLD,scope_id,"credit_shortage");
    validate_episode_config(EPISODE_ENABLE,SILENCE_THRESHOLD,WINDOW_BASIS,scope_id);
    validate_phase_config(PHASE_ENABLE,EPISODE_ENABLE,WINDOW_BASIS,PHASE_N,PHASE_MIN_SPAN,PHASE_K,
      PHASE_STEADY_ENTER_ABS,PHASE_STEADY_ENTER_REL,PHASE_STEADY_EXIT_ABS,PHASE_STEADY_EXIT_REL,
      PHASE_RMS_ENTER_ABS,PHASE_RMS_ENTER_REL,PHASE_RMS_EXIT_ABS,PHASE_RMS_EXIT_REL,
      PHASE_TREND_ABS,PHASE_TREND_REL,scope_id);
    source_handle=register_point(scope_id,monitor_path,WINDOW_BASIS,
                                 WINDOW_WIDTH,UPDATE_STRIDE,CLOCK_CONTEXT);
    transport_source=point_source_handle(source_handle);
  end
  always @(record_toggle)
    if (monitor_ready && raw_record.record_seq!=0) publish_frame(transport_source,raw_record);
  always @(control_toggle)
    if (monitor_ready && raw_control.control_seq!=0) publish_control(transport_source,raw_control);
  bw_point_recorder #(.FIXED_BYTES(FIXED_BYTES),.PROTOCOL(PROTOCOL),
                       .DYNAMIC_BYTES(DYNAMIC_BYTES)) recorder
    (.scope_id(scope_id),.clk(clk),.reset_n(reset_n),.valid(valid),.ready(ready),.flitv(flitv),.lcrdv(lcrdv),
     .size_bytes(size_bytes),.size_known(size_known),.sampled_view(sampled_view),
     .record(raw_record),.record_toggle(record_toggle),
     .control(raw_control),.control_toggle(control_toggle));
  bw_debug_hints #(.PROTOCOL(PROTOCOL),.CREDIT_ENABLE(CREDIT_ENABLE),
    .CREDIT_CAPACITY(CREDIT_CAPACITY),.CREDIT_INITIAL(CREDIT_INITIAL),
    .CREDIT_INITIAL_KNOWN(CREDIT_INITIAL_KNOWN),.CREDIT_RETURN_TIMING(CREDIT_RETURN_TIMING),
    .BACKPRESSURE_ENABLE(BACKPRESSURE_ENABLE),.BACKPRESSURE_BASIS(BACKPRESSURE_BASIS),
    .BACKPRESSURE_THRESHOLD(BACKPRESSURE_THRESHOLD),.SHORTAGE_ENABLE(SHORTAGE_ENABLE),
    .SHORTAGE_BASIS(SHORTAGE_BASIS),.SHORTAGE_THRESHOLD(SHORTAGE_THRESHOLD)) hints
    (.scope_id(scope_id),.reset_n(reset_n),.clk(clk),.valid(valid),.ready(ready),.flitv(flitv),.lcrdv(lcrdv),
     .sampled_view(sampled_view),.record(raw_record),
     .record_toggle(record_toggle),.credit_supported(credit_supported),.credit_enabled(credit_enabled),
     .credit_trusted(credit_trusted),.credit_anomaly(credit_anomaly),.credit_state(credit_state),
     .credit_reason(credit_reason),.credit_balance(credit_balance),
     .credit_last_trusted_balance(credit_last_trusted_balance),.credit_available_before(credit_available_before),
     .credit_attempted_balance(credit_attempted_balance),.credit_permission_known(credit_permission_known),
     .credit_send_permitted(credit_send_permitted),.credit_shortage_known(credit_shortage_known),
     .credit_shortage(credit_shortage),.credit_anomaly_count(credit_anomaly_count),
     .credit_result_seq(credit_result_seq),.credit_epoch(credit_epoch),.credit_update_ticks(credit_update_ticks),
     .credit_record_seq(credit_record_seq),.backpressure_result(backpressure_result),.shortage_result(shortage_result));
  bw_stats_core #(.WINDOW_BASIS(WINDOW_BASIS),.WINDOW_WIDTH(WINDOW_WIDTH),
                  .UPDATE_STRIDE(UPDATE_STRIDE),.EPISODE_ENABLE(EPISODE_ENABLE),
                  .SILENCE_THRESHOLD(SILENCE_THRESHOLD),
                  .PHASE_ENABLE(PHASE_ENABLE),
                  .PHASE_N(PHASE_N),
                  .PHASE_MIN_SPAN(PHASE_MIN_SPAN),
                  .PHASE_K(PHASE_K),
                  .PHASE_STEADY_ENTER_ABS(PHASE_STEADY_ENTER_ABS),
                  .PHASE_STEADY_ENTER_REL(PHASE_STEADY_ENTER_REL),
                  .PHASE_STEADY_EXIT_ABS(PHASE_STEADY_EXIT_ABS),
                  .PHASE_STEADY_EXIT_REL(PHASE_STEADY_EXIT_REL),
                  .PHASE_RMS_ENTER_ABS(PHASE_RMS_ENTER_ABS),
                  .PHASE_RMS_ENTER_REL(PHASE_RMS_ENTER_REL),
                  .PHASE_RMS_EXIT_ABS(PHASE_RMS_EXIT_ABS),
                  .PHASE_RMS_EXIT_REL(PHASE_RMS_EXIT_REL),
                  .PHASE_TREND_ABS(PHASE_TREND_ABS),
                  .PHASE_TREND_REL(PHASE_TREND_REL)) core
    (.scope_id(scope_id),.scope_kind(scope_kind),.record(raw_record),.record_toggle(record_toggle),
     .stats_reset_n(reset_n),.accepted_record_seq(accepted_record_seq),
     .progress_watermark_ticks(BW_U64_MAX),
     .member_control('0),.member_control_toggle(1'b0),.accepted_control_count(),
     .stats_epoch(stats_epoch),.result_seq(result_seq),.total_bytes(total_bytes),.total_events(total_events),
     .window_start_ticks(window_start_ticks),.window_end_ticks(window_end_ticks),
     .window_start_cycle(window_start_cycle),.window_end_cycle(window_end_cycle),
     .coverage_ticks(coverage_ticks),.coverage_cycles(coverage_cycles),
     .window_bytes(window_bytes),.window_events(window_events),.bandwidth_gbps(bandwidth_gbps),
     .bytes_per_cycle(bytes_per_cycle),.window_warmup(window_warmup),.window_full(window_full),
     .bytes_complete(bytes_complete),.events_complete(events_complete),
     .denominator_valid(denominator_valid),.window_valid(window_valid),
     .member_reset_coverage(member_reset_coverage),
     .episode_active(episode_active),.episode_status(episode_status),.episode_id(episode_id),
     .episode_result_seq(episode_result_seq),.episode_first_ticks(episode_first_ticks),
     .episode_last_ticks(episode_last_ticks),.episode_tail_ticks(episode_tail_ticks),
     .episode_confirmation_ticks(episode_confirmation_ticks),.episode_first_cycle(episode_first_cycle),
     .episode_last_cycle(episode_last_cycle),.episode_tail_cycle(episode_tail_cycle),
     .episode_bytes(episode_bytes),.episode_events(episode_events),.episode_duration_ticks(episode_duration_ticks),
     .episode_first_known(episode_first_known),.episode_last_known(episode_last_known),
     .episode_tail_known(episode_tail_known),.episode_bytes_complete(episode_bytes_complete),
     .episode_events_complete(episode_events_complete),.episode_member_reset_coverage(episode_member_reset_coverage),
     .episode_duration_valid(episode_duration_valid),.episode_e2e_valid(episode_e2e_valid),
     .episode_e2e_gbps(episode_e2e_gbps),.episode_result(episode_result),
     .phase_current(phase_current),
     .phase_candidate(phase_candidate),
     .phase_active(phase_active),
     .phase_eligible(phase_eligible),
     .phase_evidence_continuous(phase_evidence_continuous),
     .phase_evidence_sufficient(phase_evidence_sufficient),
     .phase_fit_valid(phase_fit_valid),
     .phase_id(phase_id),
     .phase_result_seq(phase_result_seq),
     .phase_window_seq(phase_window_seq),
     .phase_evidence_count(phase_evidence_count),
     .phase_evidence_span(phase_evidence_span),
     .phase_candidate_count(phase_candidate_count),
     .phase_candidate_ticks(phase_candidate_ticks),
     .phase_candidate_total_bytes(phase_candidate_total_bytes),
     .phase_candidate_total_events(phase_candidate_total_events),
     .phase_start_ticks(phase_start_ticks),
     .phase_confirmation_ticks(phase_confirmation_ticks),
     .phase_fit_mean(phase_fit_mean),
     .phase_fit_delta(phase_fit_delta),
     .phase_fit_rms(phase_fit_rms),
     .phase_result(phase_result));
endmodule
