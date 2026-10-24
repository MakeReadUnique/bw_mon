module bw_debug_hints #(
  parameter bw_mon_pkg::bw_protocol_t PROTOCOL = bw_mon_pkg::BW_VALID_ONLY,
  parameter bit CREDIT_ENABLE = 0,
  parameter logic [63:0] CREDIT_CAPACITY = 64'bx,
  parameter logic [63:0] CREDIT_INITIAL = 64'bx,
  parameter bit CREDIT_INITIAL_KNOWN = 0,
  parameter bw_mon_pkg::bw_credit_return_t CREDIT_RETURN_TIMING = bw_mon_pkg::BW_RETURN_NEXT_CYCLE
) (
  input string scope_id,
  input logic reset_n,
  input bw_mon_pkg::bw_sample_t sampled_view,
  input bw_mon_pkg::bw_record_t record,
  input bit record_toggle,
  output bit credit_supported = (PROTOCOL == bw_mon_pkg::BW_CREDIT),
  output bit credit_enabled = CREDIT_ENABLE,
  output bit credit_trusted = 0,
  output bit credit_anomaly = 0,
  output bw_mon_pkg::bw_credit_state_t credit_state = bw_mon_pkg::BW_CREDIT_UNKNOWN,
  output bw_mon_pkg::bw_credit_reason_t credit_reason = bw_mon_pkg::BW_CREDIT_NO_ERROR,
  output logic [63:0] credit_balance = 'x,
  output logic [63:0] credit_last_trusted_balance = 'x,
  output logic [64:0] credit_available_before = 'x,
  output logic signed [65:0] credit_attempted_balance = 'x,
  output bit credit_permission_known = 0,
  output logic credit_send_permitted = 1'bx,
  output bit credit_shortage_known,
  output logic credit_shortage,
  output bw_mon_pkg::bw_u64_t credit_anomaly_count = 0,
  output bw_mon_pkg::bw_u64_t credit_result_seq = 0,
  output bw_mon_pkg::bw_u64_t credit_epoch = 0,
  output bw_mon_pkg::bw_u64_t credit_update_ticks = 0,
  output bw_mon_pkg::bw_u64_t credit_record_seq = 0
);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bit configured = 0;
  bit in_reset = 0;

  // This is a trusted available-balance condition, not evidence of demand.
  always_comb begin
    credit_shortage_known=credit_supported && credit_enabled && credit_trusted && (reset_n===1'b1);
    credit_shortage=credit_shortage_known ? (credit_balance==0) : 1'bx;
  end

  task automatic seed_ledger();
    credit_anomaly=0;
    credit_permission_known=0;credit_send_permitted=1'bx;
    credit_available_before='x;credit_attempted_balance='x;
    if(CREDIT_INITIAL_KNOWN) begin
      credit_balance=CREDIT_INITIAL;
      credit_last_trusted_balance=CREDIT_INITIAL;
      credit_trusted=1;credit_state=BW_CREDIT_KNOWN;credit_reason=BW_CREDIT_NO_ERROR;
    end else begin
      credit_balance='x;credit_last_trusted_balance='x;
      credit_trusted=0;credit_state=BW_CREDIT_UNKNOWN;credit_reason=BW_CREDIT_INITIAL_UNKNOWN;
    end
  endtask

  task automatic lose_trust(bw_credit_reason_t reason,bw_u64_t at_ticks);
    credit_balance='x;credit_trusted=0;credit_state=BW_CREDIT_UNKNOWN;
    // Once the ledger is lost, further sends cannot establish a new balance.
    // Preserve the first diagnostic until an explicit known reset restores it.
    if(!credit_anomaly) begin
      credit_anomaly=1;credit_reason=reason;
      credit_anomaly_count=checked_add(credit_anomaly_count,1,{scope_id," credit anomaly count"});
      $display("BW_HINT_CREDIT_ANOMALY scope=%s time_ticks=%0d record_seq=%0d reason=%s last_trusted=%0d send=%b return=%b attempted=%0d",
        scope_id,at_ticks,credit_record_seq,credit_reason_name(reason),credit_last_trusted_balance,
        sampled_view.flitv,sampled_view.lcrdv,credit_attempted_balance);
    end
  endtask

  task automatic dispatch();
    bit new_frame;
    bw_u64_t at_ticks;
    bit [64:0] available;
    bit signed [65:0] candidate;
    if(!configured) return;
    new_frame=(record.record_seq!=0 && record.record_seq!=credit_record_seq);
    at_ticks=new_frame ? record.timestamp_ticks : bw_u64_t'($time);
    if(new_frame) credit_record_seq=record.record_seq;
    credit_update_ticks=at_ticks;
    credit_result_seq=checked_add(credit_result_seq,1,{scope_id," credit result"});
    if(!credit_supported) begin
      credit_state=BW_CREDIT_UNSUPPORTED;credit_trusted=0;return;
    end
    if(!credit_enabled) begin
      credit_state=BW_CREDIT_DISABLED;credit_trusted=0;return;
    end
    // Live reset controls the ledger even with no sampling clock. It has
    // priority over a same-time sampled frame, which remains raw byte evidence.
    if(reset_n===1'b0) begin
      if(!in_reset) begin
        credit_epoch=checked_add(credit_epoch,1,{scope_id," credit epoch"});
        seed_ledger();
      end
      in_reset=1;credit_trusted=0;credit_state=BW_CREDIT_RESET;
      credit_permission_known=0;credit_send_permitted=1'bx;
      return;
    end
    if(reset_n!==1'b1) begin
      in_reset=0;
      lose_trust(BW_CREDIT_RESET_UNKNOWN,at_ticks);
      return;
    end
    if(in_reset) begin in_reset=0;seed_ledger();end
    if(!new_frame) return;
    credit_permission_known=0;credit_send_permitted=1'bx;
    credit_available_before='x;credit_attempted_balance='x;
    if(sampled_view.reset_n===1'b0) return;
    if(sampled_view.reset_n!==1'b1) begin lose_trust(BW_CREDIT_RESET_UNKNOWN,at_ticks);return;end
    if($isunknown({sampled_view.flitv,sampled_view.lcrdv})) begin
      lose_trust(BW_CREDIT_CONTROL_UNKNOWN,at_ticks);return;
    end
    if(!credit_trusted) return;
    available={1'b0,credit_balance};
    if(CREDIT_RETURN_TIMING==BW_RETURN_SAME_CYCLE && sampled_view.lcrdv)
      available=available+65'd1;
    // 66-bit signed arithmetic represents the entire [-1,2^64] range exactly.
    // A credit protocol violation never invokes statistical integer overflow.
    candidate=$signed({2'b00,credit_balance}) + (sampled_view.lcrdv ? 66'sd1 : 66'sd0)
                                            - (sampled_view.flitv ? 66'sd1 : 66'sd0);
    credit_available_before=available;credit_attempted_balance=candidate;
    credit_permission_known=1;credit_send_permitted=(available>=65'd1);
    if(sampled_view.flitv && available==0) begin
      lose_trust(BW_CREDIT_NO_CREDIT,at_ticks);return;
    end
    if(candidate<66'sd0) begin lose_trust(BW_CREDIT_UNDERFLOW,at_ticks);return;end
    if(candidate>$signed({2'b00,CREDIT_CAPACITY})) begin
      lose_trust(BW_CREDIT_OVERFLOW,at_ticks);return;
    end
    credit_balance=candidate[63:0];credit_last_trusted_balance=candidate[63:0];
  endtask

  initial begin
    wait(scope_id.len()!=0);
    if(credit_supported && credit_enabled) begin
      validate_credit_config(PROTOCOL,CREDIT_ENABLE,CREDIT_CAPACITY,CREDIT_INITIAL,
                             CREDIT_INITIAL_KNOWN,CREDIT_RETURN_TIMING,scope_id);
      seed_ledger();
    end
    configured=1;dispatch();
  end
  always @(record_toggle or reset_n) dispatch();
endmodule
