module tb_hint_same_cycle_live;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic lcrdv=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),.CREDIT_ENABLE(1),
    .CREDIT_CAPACITY(2),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .CREDIT_RETURN_TIMING(BW_RETURN_SAME_CYCLE),.SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_NS),
    .SHORTAGE_THRESHOLD(2)) zero(.clk(1'b0),.reset_n(1'b1),.flitv(1'b0),.lcrdv(lcrdv));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),.CREDIT_ENABLE(1),
    .CREDIT_CAPACITY(2),.CREDIT_INITIAL(1),.CREDIT_INITIAL_KNOWN(1),
    .CREDIT_RETURN_TIMING(BW_RETURN_SAME_CYCLE),.SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_NS),
    .SHORTAGE_THRESHOLD(2)) positive(.clk(1'b0),.reset_n(1'b1),.flitv(1'b0),.lcrdv(lcrdv));
  initial begin
    wait(monitor_ready);
    #1000000;lcrdv=0;#1000000;lcrdv=1;#1;
    if(zero.shortage_active || zero.shortage_hit || zero.shortage_duration_ticks!=1000000 ||
       zero.shortage_end_reason!=BW_HINT_RELEASED || zero.credit_balance!==64'd0)
      $fatal(1,"live SAME return releases shortage without a clock or ledger increment");
    #999999;lcrdv=0;#2000000;lcrdv=1'bx;#1;
    if(zero.credit_shortage_known || zero.credit_shortage!==1'bx || zero.shortage_trusted ||
       zero.shortage_active || !zero.shortage_hit || zero.shortage_trigger_ticks!=5000000 ||
       zero.shortage_end_reason!=BW_HINT_UNKNOWN || !zero.credit_trusted)
      $fatal(1,"C0/RX is unknown and threshold-equal uncertainty preserves only prior known duration");
    if(!positive.credit_shortage_known || positive.credit_shortage!==0 || !positive.shortage_trusted ||
       positive.shortage_active || !positive.credit_trusted)
      $fatal(1,"C>0 proves no shortage even with unknown live SAME return");
    #999999;lcrdv=1;#1000000;lcrdv=0;#500000;lcrdv=1'bz;#1;
    if(zero.credit_shortage_known || zero.shortage_active || zero.shortage_hit ||
       zero.shortage_duration_ticks!=500000 || !positive.credit_shortage_known || positive.credit_shortage!==0)
      $fatal(1,"RZ breaks only genuinely unknown C0 evidence, never joining it across the gap");
    #499999;lcrdv=0;#2000000;lcrdv=1;#1;
    if(zero.shortage_active || !zero.shortage_hit || zero.shortage_hit_count!=2 ||
       zero.shortage_duration_ticks!=2000000 || zero.shortage_end_reason!=BW_HINT_RELEASED ||
       zero.credit_balance!==64'd0 || positive.credit_balance!==64'd1 ||
       zero.credit_record_seq!=0 || positive.credit_record_seq!=0 || zero.total_events!=0 ||
       positive.shortage_interval_count!=0 || positive.shortage_hit_count!=0)
      $fatal(1,"stopped-clock live availability must not fabricate sampled credits/events or positive-C shortage");
    #2000000;
    if(zero.shortage_hit_count!=2 || zero.shortage_interval_count!=4)
      $fatal(1,"stale timers cannot retrigger closed SAME-cycle intervals");
    $display("TB_PASS hint_same_cycle_live");$finish;
  end
endmodule
