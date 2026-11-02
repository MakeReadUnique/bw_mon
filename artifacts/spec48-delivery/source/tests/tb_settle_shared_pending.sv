module tb_settle_shared_pending;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_u64_t retained;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("p"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2))
    p(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("g"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2))
    g(.clk(clk),.reset_n(1'b1));
  initial begin
    add_point_member("g","p");wait(monitor_ready);#1000000;clk=1;
    // Both actual-edge grants exist, but neither may be accepted before the
    // writable callback. A shared arithmetic failure cancels that work.
    #0;retained=checked_add(BW_U64_MAX,1,"shared.counter");
    #1;
    if(!monitoring_shared_disabled || retained!=BW_U64_MAX ||
       p.accepted_record_seq!=0 || g.accepted_record_seq!=0 ||
       !p.recorder.scheduler_cancelled || !p.core.scheduler_cancelled ||
       !g.collector_cancelled || !g.core.scheduler_cancelled)
      $fatal(1,"shared cancellation must end pending grants without successful receipts");
    #1000000;
    if($time!=2000002 || monitoring_failure_count!=1)
      $fatal(1,"shared failure must leave later user simulation runnable");
    $display("TB_PASS settle_shared_pending accepted=0 continued_ticks=%0d",$time);$finish;
  end
endmodule
