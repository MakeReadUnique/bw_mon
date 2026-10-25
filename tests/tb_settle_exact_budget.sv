module tb_settle_exact_budget;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  localparam bw_u64_t LIMIT=64'd40000000000;
  logic clk=0;
  bit end_requested=0;
  bit transport_complete=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2),.EXPECTED_GROUP_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("settle.end.p0"),.WINDOW_WIDTH(40000),.UPDATE_STRIDE(1),.FIXED_BYTES(8),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(3)) p0(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("settle.end.p1"),.WINDOW_WIDTH(40000),.UPDATE_STRIDE(1),.FIXED_BYTES(16),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(3)) p1(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("settle.end.child"),.WINDOW_WIDTH(40000),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(3)) child(.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("settle.end.parent"),.WINDOW_WIDTH(40000),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(3)) parent(.clk(clk),.reset_n(1'b1));
  settle_exact_budget_clock driver();
  initial begin
    define_group("settle.end.child",1);add_point_member("settle.end.child","settle.end.p0");
    define_group("settle.end.parent",2);add_group_member("settle.end.parent","settle.end.child");
    add_point_member("settle.end.parent","settle.end.p1");finish_configuration();wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    #(LIMIT-$time);end_requested<=1;
  end
  function automatic bit ready_to_finish();
    return $time==LIMIT && p0.result_seq==40000 && p1.result_seq==40000 &&
      child.result_seq==40000 && parent.result_seq==40000 &&
      p0.accepted_record_seq==2 && p1.accepted_record_seq==2 &&
      child.accepted_record_seq==2 && parent.accepted_record_seq==2;
  endfunction
  function automatic void final_verdict();
    if(!ready_to_finish() || core_failure_pending() ||
       p0.window_start_ticks!=0 || p0.window_end_ticks!=LIMIT ||
       child.window_end_ticks!=LIMIT || parent.window_end_ticks!=LIMIT ||
       p0.window_bytes!=8 || p1.window_bytes!=16 || child.window_bytes!=8 || parent.window_bytes!=24 ||
       p0.total_bytes!=16 || p1.total_bytes!=32 || child.total_bytes!=16 || parent.total_bytes!=48 ||
       !p0.window_full || !p1.window_full || !child.window_full || !parent.window_full ||
       !p0.window_valid || !child.window_valid || !parent.window_valid ||
       !transport_complete ||
       $abs(parent.bandwidth_gbps-0.0006)>1e-12)
      $fatal(1,"all exact-budget windows, late ReNBA raw edge and direct ACKs must settle at40us without drain");
    $display("TB_PASS settle_exact_budget ticks=%0d windows=%0d receipts=%0d",$time,4*p0.result_seq,4*p0.accepted_record_seq);
    $finish;
  endfunction
  initial begin
    bw_notification child_notice,parent_notice;
    wait(monitor_ready);child_notice=group_notification(child.group_handle);parent_notice=group_notification(parent.group_handle);
    forever begin
      if(end_requested)transport_complete=(retained_frame_count(p0.transport_source)==0 &&
        retained_frame_count(p1.transport_source)==0 && retained_frame_count(child.transport_source)==0 &&
        acknowledged_frame_seq(parent.group_handle,0)==2);
      @(end_requested or child_notice.seq or parent_notice.seq or slot_settlement_generation);
    end
  end
  always @(end_requested or p0.result_seq or p1.result_seq or child.result_seq or parent.result_seq or
           p0.accepted_record_seq or p1.accepted_record_seq or child.accepted_record_seq or parent.accepted_record_seq)
    if(end_requested)begin
      EXACT_BUDGET_SETTLED:assert final(ready_to_finish()) final_verdict();else final_verdict();
    end
endmodule
program settle_exact_budget_clock;
  timeunit 1fs;timeprecision 1fs;
  initial begin
    wait(bw_mon_pkg::monitor_ready);#(64'd40000000000);
    tb_settle_exact_budget.clk<=1;
    wait(1'b0);
  end
endprogram
