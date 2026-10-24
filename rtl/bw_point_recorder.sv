module bw_point_recorder #(
  parameter bw_mon_pkg::bw_u64_t FIXED_BYTES = 0,
  parameter bw_mon_pkg::bw_protocol_t PROTOCOL = bw_mon_pkg::BW_VALID_ONLY,
  parameter bit DYNAMIC_BYTES = 0
) (
  input string scope_id,
  input logic clk,
  input logic reset_n,
  input logic valid = 1'b0,
  input logic ready = 1'b0,
  input logic flitv = 1'b0,
  input logic lcrdv = 1'b0,
  input logic [63:0] size_bytes = 64'bx,
  input logic size_known = 1'b0,
  output bw_mon_pkg::bw_sample_t sampled_view,
  output bw_mon_pkg::bw_record_t record,
  output bit record_toggle = 0
);
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_u64_t record_seq = 0, edge_index = 0;
  logic transfer;
  initial begin
    record = '0;
    sampled_view = 'x;
    wait(scope_id.len()!=0);
    if ($isunknown(PROTOCOL) || !(PROTOCOL inside {BW_VALID_ONLY,BW_VALID_READY,BW_CREDIT}))
      core_error("PROTOCOL_CONFIG",scope_id,"unsupported protocol");
    if (!DYNAMIC_BYTES && FIXED_BYTES > 64'hffffffff)
      core_error("BYTE_CONFIG",scope_id,"single transfer exceeds 2^32-1 bytes");
  end
  always @(posedge clk) begin
    if (monitor_ready && $time > measurement_start_ticks) begin
      // Capture all raw protocol and accounting fields in one active-region
      // action. DUT nonblocking updates cannot mix a new size with old control.
      sampled_view.reset_n = reset_n;
      sampled_view.valid = valid;
      sampled_view.ready = ready;
      sampled_view.flitv = flitv;
      sampled_view.lcrdv = lcrdv;
      sampled_view.size_bytes = size_bytes;
      sampled_view.size_known = size_known;
      edge_index = checked_add(edge_index,1,{scope_id," edge"});
      record_seq = checked_add(record_seq,1,{scope_id," record"});
      record = '0;
      record.timestamp_ticks = $time;
      record.edge_index = edge_index;
      record.record_seq = record_seq;
      record.reset_n = sampled_view.reset_n;
      record.events_complete = 1;
      record.bytes_complete = 1;
      case (PROTOCOL)
        BW_VALID_ONLY:  transfer = sampled_view.valid;
        BW_VALID_READY: transfer = sampled_view.valid & sampled_view.ready;
        BW_CREDIT:     transfer = sampled_view.flitv;
        default:       transfer = 1'bx;
      endcase
      if (sampled_view.reset_n === 1'b0) record.reset_points = 1;
      else if (sampled_view.reset_n !== 1'b1) begin
        record.events_complete = 0;
        record.bytes_complete = 0;
      end else if (transfer === 1'b1) begin
        record.event_inc = 1;
        if (!DYNAMIC_BYTES) record.byte_inc = FIXED_BYTES;
        else if (sampled_view.size_known === 1'b1 && !$isunknown(sampled_view.size_bytes)) begin
          if (sampled_view.size_bytes > 64'hffffffff)
            core_error("TRANSFER_BYTES",scope_id,
              $sformatf("sampled bytes=%0d exceeds 2^32-1",sampled_view.size_bytes));
          record.byte_inc = sampled_view.size_bytes;
        end else record.bytes_complete = 0;
      end else if (transfer !== 1'b0) begin
        record.events_complete = 0;
        record.bytes_complete = 0;
      end
      record_toggle <= !record_toggle;
    end
  end
endmodule
