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

  // Unnamed block deliberately preserves exactly the public instance scope.
  initial begin
    monitor_path=$sformatf("%m");
    scope_id=(POINT_ID=="__BW_AUTO__") ? monitor_path : POINT_ID;
    validate_point_protocol(PROTOCOL,DYNAMIC_BYTES,FIXED_BYTES,scope_id);
    validate_credit_config(PROTOCOL,CREDIT_ENABLE,CREDIT_CAPACITY,CREDIT_INITIAL,
                           CREDIT_INITIAL_KNOWN,CREDIT_RETURN_TIMING,scope_id);
    validate_episode_config(EPISODE_ENABLE,SILENCE_THRESHOLD,WINDOW_BASIS,scope_id);
    validate_phase_config(PHASE_ENABLE,EPISODE_ENABLE,WINDOW_BASIS,PHASE_N,PHASE_MIN_SPAN,PHASE_K,
      PHASE_STEADY_ENTER_ABS,PHASE_STEADY_ENTER_REL,PHASE_STEADY_EXIT_ABS,PHASE_STEADY_EXIT_REL,
      PHASE_RMS_ENTER_ABS,PHASE_RMS_ENTER_REL,PHASE_RMS_EXIT_ABS,PHASE_RMS_EXIT_REL,
      PHASE_TREND_ABS,PHASE_TREND_REL,scope_id);
    source_handle=register_point(scope_id,monitor_path,WINDOW_BASIS,
                                 WINDOW_WIDTH,UPDATE_STRIDE,CLOCK_CONTEXT);
  end
  bw_point_recorder #(.FIXED_BYTES(FIXED_BYTES),.PROTOCOL(PROTOCOL),
                       .DYNAMIC_BYTES(DYNAMIC_BYTES)) recorder
    (.scope_id(scope_id),.clk(clk),.reset_n(reset_n),.valid(valid),.ready(ready),.flitv(flitv),.lcrdv(lcrdv),
     .size_bytes(size_bytes),.size_known(size_known),.sampled_view(sampled_view),
     .record(raw_record),.record_toggle(record_toggle),
     .control(raw_control),.control_toggle(control_toggle));
  bw_debug_hints #(.PROTOCOL(PROTOCOL),.CREDIT_ENABLE(CREDIT_ENABLE),
    .CREDIT_CAPACITY(CREDIT_CAPACITY),.CREDIT_INITIAL(CREDIT_INITIAL),
    .CREDIT_INITIAL_KNOWN(CREDIT_INITIAL_KNOWN),.CREDIT_RETURN_TIMING(CREDIT_RETURN_TIMING)) hints
    (.scope_id(scope_id),.reset_n(reset_n),.sampled_view(sampled_view),.record(raw_record),
     .record_toggle(record_toggle),.credit_supported(credit_supported),.credit_enabled(credit_enabled),
     .credit_trusted(credit_trusted),.credit_anomaly(credit_anomaly),.credit_state(credit_state),
     .credit_reason(credit_reason),.credit_balance(credit_balance),
     .credit_last_trusted_balance(credit_last_trusted_balance),.credit_available_before(credit_available_before),
     .credit_attempted_balance(credit_attempted_balance),.credit_permission_known(credit_permission_known),
     .credit_send_permitted(credit_send_permitted),.credit_shortage_known(credit_shortage_known),
     .credit_shortage(credit_shortage),.credit_anomaly_count(credit_anomaly_count),
     .credit_result_seq(credit_result_seq),.credit_epoch(credit_epoch),.credit_update_ticks(credit_update_ticks),
     .credit_record_seq(credit_record_seq));
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
