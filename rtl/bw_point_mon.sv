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
  parameter logic [63:0] SILENCE_THRESHOLD = 0
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
                  .SILENCE_THRESHOLD(SILENCE_THRESHOLD)) core
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
     .episode_e2e_gbps(episode_e2e_gbps),.episode_result(episode_result));
endmodule
