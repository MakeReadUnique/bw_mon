module bw_point_recorder #(
  parameter bw_mon_pkg::bw_u64_t FIXED_BYTES = 0
) (
  input logic clk,
  input logic reset_n,
  input logic valid,
  output bw_mon_pkg::bw_record_t record,
  output bit record_toggle = 0
);
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_u64_t record_seq = 0, edge_index = 0;
  initial begin
    record = '0;
    if (FIXED_BYTES > 64'hffffffff)
      core_error("BYTE_CONFIG",$sformatf("%m"),"single transfer exceeds 2^32-1 bytes");
  end
  always @(posedge clk) begin
    if (monitor_ready && $time > measurement_start_ticks) begin
      edge_index = checked_add(edge_index,1,$sformatf("%m edge"));
      record_seq = checked_add(record_seq,1,$sformatf("%m record"));
      record = '0;
      record.timestamp_ticks = $time;
      record.edge_index = edge_index;
      record.record_seq = record_seq;
      record.reset_n = reset_n;
      record.events_complete = 1;
      record.bytes_complete = 1;
      if (reset_n === 1'b0) record.reset_points = 1;
      else if (reset_n !== 1'b1) begin
        record.events_complete = 0;
        record.bytes_complete = 0;
      end else if (valid === 1'b1) begin
        record.event_inc = 1;
        record.byte_inc = FIXED_BYTES;
      end else if (valid !== 1'b0) begin
        record.events_complete = 0;
        record.bytes_complete = 0;
      end
      record_toggle <= !record_toggle;
    end
  end
endmodule
