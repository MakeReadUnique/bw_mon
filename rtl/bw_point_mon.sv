module bw_point_mon #(
  parameter string POINT_ID = "__BW_AUTO__",
  parameter string CLOCK_CONTEXT = "default",
  parameter bw_mon_pkg::bw_basis_t WINDOW_BASIS = bw_mon_pkg::BW_NS,
  parameter bw_mon_pkg::bw_u64_t WINDOW_WIDTH = 0,
  parameter bw_mon_pkg::bw_u64_t UPDATE_STRIDE = 0,
  parameter bw_mon_pkg::bw_u64_t FIXED_BYTES = 0,
  parameter bw_mon_pkg::bw_protocol_t PROTOCOL = bw_mon_pkg::BW_VALID_ONLY,
  parameter bit DYNAMIC_BYTES = 0
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
  // Until credit diagnostics are configured their capability and trust remain
  // explicit; neither state participates in byte accounting.
  bit credit_supported = (PROTOCOL == BW_CREDIT);
  bit credit_enabled = 0;
  bit credit_trusted = 0;
  bit record_toggle, control_toggle;
  bw_u64_t accepted_record_seq;
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
    source_handle=register_point(scope_id,monitor_path,WINDOW_BASIS,
                                 WINDOW_WIDTH,UPDATE_STRIDE,CLOCK_CONTEXT);
  end
  bw_point_recorder #(.FIXED_BYTES(FIXED_BYTES),.PROTOCOL(PROTOCOL),
                       .DYNAMIC_BYTES(DYNAMIC_BYTES)) recorder
    (.scope_id(scope_id),.clk(clk),.reset_n(reset_n),.valid(valid),.ready(ready),.flitv(flitv),.lcrdv(lcrdv),
     .size_bytes(size_bytes),.size_known(size_known),.sampled_view(sampled_view),
     .record(raw_record),.record_toggle(record_toggle),
     .control(raw_control),.control_toggle(control_toggle));
  bw_stats_core #(.WINDOW_BASIS(WINDOW_BASIS),.WINDOW_WIDTH(WINDOW_WIDTH),
                  .UPDATE_STRIDE(UPDATE_STRIDE)) core
    (.scope_id(scope_id),.record(raw_record),.record_toggle(record_toggle),
     .stats_reset_n(reset_n),.accepted_record_seq(accepted_record_seq),
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
