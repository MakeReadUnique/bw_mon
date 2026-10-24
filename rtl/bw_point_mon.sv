module bw_point_mon #(
  parameter string POINT_ID = "__BW_AUTO__",
  parameter string CLOCK_CONTEXT = "default",
  parameter bw_mon_pkg::bw_basis_t WINDOW_BASIS = bw_mon_pkg::BW_NS,
  parameter bw_mon_pkg::bw_u64_t WINDOW_WIDTH = 0,
  parameter bw_mon_pkg::bw_u64_t UPDATE_STRIDE = 0,
  parameter bw_mon_pkg::bw_u64_t FIXED_BYTES = 0
) (
  input logic clk,
  input logic reset_n,
  input logic valid
);
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  string scope_id, monitor_path;
  bw_scope_t scope_kind = BW_POINT;
  int source_handle;
  bw_record_t raw_record;
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
    source_handle=register_point(scope_id,monitor_path,WINDOW_BASIS,
                                 WINDOW_WIDTH,UPDATE_STRIDE,CLOCK_CONTEXT);
  end
  bw_point_recorder #(.FIXED_BYTES(FIXED_BYTES)) recorder
    (.clk(clk),.reset_n(reset_n),.valid(valid),.record(raw_record),.record_toggle(record_toggle));
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
