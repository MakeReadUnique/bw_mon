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
  localparam bw_scope_t scope_kind=BW_POINT;
  `include "bw_scope_runtime.svh"
  bw_u64_t record_seq = 0, edge_index = 0;
  bw_u64_t control_seq = 0, source_epoch = 0;
  bw_u64_t requested_actions = 0, consumed_actions = 0;
  bw_u64_t settlement_required=0;
  bw_u64_t last_assert_ticks = 0;
  bit reset_observed = 0, assertion_observed = 0;
  logic observed_reset;
  bit external_reset_capture=0;
  bit reset_observer_ready=0;
  bit publication_receipts=0;
  bw_u64_t published_control_seq=0,published_record_seq=0;
  function void use_external_reset_capture();external_reset_capture=1;endfunction
  function void use_publication_receipts();publication_receipts=1;endfunction
  function void note_control_published(logic [63:0] sequence_number);
    if($isunknown(sequence_number))begin core_error("INTEGER_UNKNOWN",scope_id,"control publication receipt is unknown");
    return;end
    if(sequence_number!=control.control_seq || sequence_number<=published_control_seq)
      core_error("RECORDER_RECEIPT",scope_id,"control publication receipt does not match the held payload");
    if(runtime_failed())return;
    if(!runtime_failed())published_control_seq=sequence_number;
  endfunction
  function void note_record_published(logic [63:0] sequence_number);
    if($isunknown(sequence_number))begin core_error("INTEGER_UNKNOWN",scope_id,"frame publication receipt is unknown");
    return;end
    if(sequence_number!=record.record_seq || sequence_number<=published_record_seq)
      core_error("RECORDER_RECEIPT",scope_id,"frame publication receipt does not match the held payload");
    if(runtime_failed())return;
    if(!runtime_failed())published_record_seq=sequence_number;
  endfunction
  function void apply_captured_reset(logic value,bw_u64_t ticks);observe_reset(value,ticks);
    if(runtime_failed())return;endfunction
  `include "bw_reset_capture.svh"
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
    initialize_reset_capture($sformatf("%m"),"reset_n");
  end

  function automatic void observe_reset(logic reset_value,bw_u64_t at_ticks);
    bw_control_t next_control;
    if(scope_failed(BW_POINT,scope_id))return;
    if (reset_observed && observed_reset === reset_value) return;
    check_monitor_time(at_ticks,scope_id);
    if(runtime_failed())return;
    if (reset_value === 1'b0 && (!reset_observed || observed_reset !== 1'b0)) begin
      source_epoch=checked_add(source_epoch,1,{scope_id," source epoch"});
      if(runtime_failed())return;
      last_assert_ticks=at_ticks;
      assertion_observed=1;
    end
    observed_reset=reset_value;
    reset_observed=1;
    control_seq=checked_add(control_seq,1,{scope_id," control"});
    if(runtime_failed())return;
    next_control='0;
    next_control.timestamp_ticks=at_ticks;
    next_control.control_seq=control_seq;
    next_control.source_epoch=source_epoch;
    next_control.point_handle=point_handle_for_id(scope_id);
    next_control.reset_n=reset_value;
    check_storage_growth(pending_controls.size(),scope_id,"recorder.controls",next_control.timestamp_ticks,edge_index,record_seq);
    if(runtime_failed())return;
    pending_controls.push_back(next_control);
    requested_actions=checked_add(requested_actions,1,scope_id);
    if(runtime_failed())return;
    settlement_required=request_slot_settlement(scope_id);
  endfunction

  initial begin
    wait(monitor_ready);
    if(!external_reset_capture)begin
      wait(reset_capture_handle!=null);reset_observer_ready=1;bw_native_reset_snapshot(reset_capture_handle);
    end
  end

  always @(posedge clk) begin : capture_edge
    pending_sample_t sample;
    if (monitor_ready && $time > measurement_start_ticks && !scope_failed(BW_POINT,scope_id)) begin
`ifdef BW_MON_TEST_FAULTS
      if(take_point_fault(scope_id,"capture"))disable capture_edge;
`endif
      check_monitor_time($time,scope_id);
      if(runtime_failed())disable capture_edge;
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
      if(runtime_failed())disable capture_edge;
      record_seq = checked_add(record_seq,1,{scope_id," record"});
      if(runtime_failed())disable capture_edge;
      sample.timestamp_ticks=$time;
      sample.edge_index=edge_index;
      sample.record_seq=record_seq;
      check_storage_growth(pending_samples.size(),scope_id,"recorder.samples",sample.timestamp_ticks,sample.edge_index,sample.record_seq);
      if(!runtime_failed())begin
        pending_samples.push_back(sample);
        point_capture_receipt(scope_id,sample.record_seq);
        requested_actions=checked_add(requested_actions,1,scope_id);
        if(runtime_failed())disable capture_edge;
        settlement_required=request_slot_settlement(scope_id);
      end
    end
  end

  task automatic drain_actions();
    pending_sample_t sample;
    logic transfer;
    while (consumed_actions != requested_actions && !scope_failed(BW_POINT,scope_id)) begin
      wait(slot_settlement_generation>=settlement_required || scope_failed(BW_POINT,scope_id));
      if(scope_failed(BW_POINT,scope_id))return;
      if (pending_controls.size()!=0) begin
        control=pending_controls.pop_front();
        consumed_actions=checked_add(consumed_actions,1,scope_id);
        if(runtime_failed())return;
        control_toggle<=!control_toggle;
        @(control_toggle);
        if(publication_receipts)wait(published_control_seq>=control.control_seq || scope_failed(BW_POINT,scope_id));
        if(scope_failed(BW_POINT,scope_id))return;
        // A ReNBA waiter can wake before module consumers copy the payload.
        // Hold it through a writable quiescent generation before exposing the
        // next item, including multiple controls captured at the same tick.
        settlement_required=request_slot_settlement(scope_id);
        wait(slot_settlement_generation>=settlement_required || runtime_failed());
        if(runtime_failed())return;
        continue;
      end
      sample=pending_samples.pop_front();
      point_inflight_receipt(scope_id,sample.record_seq);
`ifdef BW_MON_TEST_FAULTS
      if(take_point_fault(scope_id,"held"))begin
        // A held tuple remains an obligation even though its queue is empty.
        wait(scope_failed(BW_POINT,scope_id));return;
      end
`endif
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
          if(runtime_failed())return;
          record.byte_inc = sampled_view.size_bytes;
        end else record.bytes_complete = 0;
      end else if (transfer !== 1'b0) begin
        record.events_complete = 0;
        record.bytes_complete = 0;
      end
      consumed_actions=checked_add(consumed_actions,1,scope_id);
      if(runtime_failed())return;
      record_toggle <= !record_toggle;
      @(record_toggle);
      if(publication_receipts)wait(published_record_seq>=record.record_seq || scope_failed(BW_POINT,scope_id));
      if(scope_failed(BW_POINT,scope_id))return;
      settlement_required=request_slot_settlement(scope_id);
      wait(slot_settlement_generation>=settlement_required || runtime_failed());
      if(runtime_failed())return;
    end
  endtask

  bw_point_record_scheduler scheduler();
endmodule

// A private coordinator waits for the shared writable end-of-slot generation.
// Upward module-type references bind to each owning instance.
program bw_point_record_scheduler;
  timeunit 1fs; timeprecision 1fs;
  initial forever begin
    wait(!bw_mon_pkg::scope_failed(bw_mon_pkg::bw_scope_t'(bw_point_recorder.scope_kind),bw_point_recorder.scope_id) && bw_point_recorder.requested_actions != bw_point_recorder.consumed_actions);
    bw_point_recorder.drain_actions();
  end
endprogram
