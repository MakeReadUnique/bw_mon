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
  parameter bw_mon_pkg::bw_credit_return_t CREDIT_RETURN_TIMING = bw_mon_pkg::BW_RETURN_NEXT_CYCLE
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
  bit record_toggle;
  bw_u64_t stats_epoch,result_seq,total_bytes,total_events;
  bw_u64_t window_start_ticks,window_end_ticks,window_start_cycle,window_end_cycle;
  bw_u64_t coverage_ticks,coverage_cycles,window_bytes,window_events;
  real bandwidth_gbps,bytes_per_cycle;
  bit window_warmup,window_full,bytes_complete,events_complete;
  bit denominator_valid,window_valid,member_reset_coverage;

  // Unnamed block deliberately preserves exactly the public instance scope.
  initial begin
    monitor_path=$sformatf("%m");
    scope_id=(POINT_ID=="__BW_AUTO__") ? monitor_path : POINT_ID;
    validate_point_protocol(PROTOCOL,DYNAMIC_BYTES,FIXED_BYTES,scope_id);
    validate_credit_config(PROTOCOL,CREDIT_ENABLE,CREDIT_CAPACITY,CREDIT_INITIAL,
                           CREDIT_INITIAL_KNOWN,CREDIT_RETURN_TIMING,scope_id);
    source_handle=register_point(scope_id,monitor_path,WINDOW_BASIS,
                                 WINDOW_WIDTH,UPDATE_STRIDE,CLOCK_CONTEXT);
  end
  bw_point_recorder #(.FIXED_BYTES(FIXED_BYTES),.PROTOCOL(PROTOCOL),
                       .DYNAMIC_BYTES(DYNAMIC_BYTES)) recorder
    (.scope_id(scope_id),.clk(clk),.reset_n(reset_n),.valid(valid),.ready(ready),.flitv(flitv),.lcrdv(lcrdv),
     .size_bytes(size_bytes),.size_known(size_known),.sampled_view(sampled_view),
     .record(raw_record),.record_toggle(record_toggle));
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
                  .UPDATE_STRIDE(UPDATE_STRIDE)) core
    (.scope_id(scope_id),.record(raw_record),.record_toggle(record_toggle),
     .stats_epoch(stats_epoch),.result_seq(result_seq),.total_bytes(total_bytes),.total_events(total_events),
     .window_start_ticks(window_start_ticks),.window_end_ticks(window_end_ticks),
     .window_start_cycle(window_start_cycle),.window_end_cycle(window_end_cycle),
     .coverage_ticks(coverage_ticks),.coverage_cycles(coverage_cycles),
     .window_bytes(window_bytes),.window_events(window_events),.bandwidth_gbps(bandwidth_gbps),
     .bytes_per_cycle(bytes_per_cycle),.window_warmup(window_warmup),.window_full(window_full),
     .bytes_complete(bytes_complete),.events_complete(events_complete),
     .denominator_valid(denominator_valid),.window_valid(window_valid),
     .member_reset_coverage(member_reset_coverage));
endmodule
