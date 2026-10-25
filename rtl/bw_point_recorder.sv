module bw_point_recorder #(
  parameter logic [63:0] FIXED_BYTES = 64'b0,
  parameter bw_mon_pkg::bw_protocol_t PROTOCOL = bw_mon_pkg::BW_VALID_ONLY,
  parameter logic [1:0] DYNAMIC_BYTES = 0
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
  output bit record_toggle = 0,
  output bw_mon_pkg::bw_control_t control,
  output bit control_toggle = 0
);
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_u64_t record_seq = 0, edge_index = 0;
  bw_u64_t control_seq = 0, source_epoch = 0;
  bw_u64_t requested_actions = 0, consumed_actions = 0;
  bw_u64_t last_assert_ticks = 0;
  bit reset_observed = 0, assertion_observed = 0;
  logic observed_reset;
  typedef struct packed {
    bw_u64_t timestamp_ticks;
    bw_u64_t record_seq;
    bw_u64_t edge_index;
    bw_sample_t sample;
  } pending_sample_t;
  pending_sample_t pending_samples[$];
  bw_control_t pending_controls[$];
  initial begin
    record = '0;
    control = '0;
    sampled_view = 'x;
    wait(scope_id.len()!=0);
    validate_point_protocol(PROTOCOL,DYNAMIC_BYTES,FIXED_BYTES,scope_id);
  end

  task automatic observe_reset();
    bw_control_t next_control;
    if (reset_observed && observed_reset === reset_n) return;
    check_monitor_time($time,scope_id);
    if (reset_n === 1'b0 && (!reset_observed || observed_reset !== 1'b0)) begin
      source_epoch=checked_add(source_epoch,1,{scope_id," source epoch"});
      last_assert_ticks=$time;
      assertion_observed=1;
    end
    observed_reset=reset_n;
    reset_observed=1;
    control_seq=checked_add(control_seq,1,{scope_id," control"});
    next_control='0;
    next_control.timestamp_ticks=$time;
    next_control.control_seq=control_seq;
    next_control.source_epoch=source_epoch;
    next_control.point_handle=point_handle_for_id(scope_id);
    next_control.reset_n=reset_n;
    check_storage_growth(pending_controls.size(),scope_id,"recorder.controls",next_control.timestamp_ticks,edge_index,record_seq);
    if(core_failure_seen)return;
    pending_controls.push_back(next_control);
    requested_actions=checked_add(requested_actions,1,scope_id);
  endtask

  initial begin
    wait(monitor_ready);
    observe_reset();
  end
  always @(reset_n) if (monitor_ready) observe_reset();

  always @(posedge clk) begin : capture_edge
    pending_sample_t sample;
    if (monitor_ready && $time > measurement_start_ticks) begin
      check_monitor_time($time,scope_id);
      // Protocol controls and size always come from the same pre-NBA beat.
      // A same-time assertion has priority; release preserves this edge view.
      sample.sample.reset_n = reset_n;
      sample.sample.valid = valid;
      sample.sample.ready = ready;
      sample.sample.flitv = flitv;
      sample.sample.lcrdv = lcrdv;
      sample.sample.size_bytes = size_bytes;
      sample.sample.size_known = size_known;
      edge_index = checked_add(edge_index,1,{scope_id," edge"});
      record_seq = checked_add(record_seq,1,{scope_id," record"});
      sample.timestamp_ticks=$time;
      sample.edge_index=edge_index;
      sample.record_seq=record_seq;
      check_storage_growth(pending_samples.size(),scope_id,"recorder.samples",sample.timestamp_ticks,sample.edge_index,sample.record_seq);
      if(!core_failure_seen)begin
        pending_samples.push_back(sample);
        requested_actions=checked_add(requested_actions,1,scope_id);
      end
    end
  end

  task automatic drain_actions();
    pending_sample_t sample;
    logic transfer;
    while (consumed_actions != requested_actions) begin
      if (pending_controls.size()!=0) begin
        control=pending_controls.pop_front();
        consumed_actions=checked_add(consumed_actions,1,scope_id);
        control_toggle<=!control_toggle;
        // Module consumers copy/persist this control before another is shown.
        @(control_toggle);
        continue;
      end
      sample=pending_samples.pop_front();
      sampled_view=sample.sample;
      if (assertion_observed && last_assert_ticks==sample.timestamp_ticks)
        sampled_view.reset_n=1'b0;
      record = '0;
      record.timestamp_ticks = sample.timestamp_ticks;
      record.edge_index = sample.edge_index;
      record.record_seq = sample.record_seq;
      record.source_epoch = source_epoch;
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
      consumed_actions=checked_add(consumed_actions,1,scope_id);
      record_toggle <= !record_toggle;
      @(record_toggle);
    end
  endtask

  bw_point_record_scheduler scheduler();
endmodule

// A private reactive coordinator waits for durable work, after module NBA
// updates settle. Upward module-type references bind to each owning instance.
program bw_point_record_scheduler;
  timeunit 1fs; timeprecision 1fs;
  initial forever begin
    wait(bw_point_recorder.requested_actions != bw_point_recorder.consumed_actions);
    bw_point_recorder.drain_actions();
  end
endprogram
