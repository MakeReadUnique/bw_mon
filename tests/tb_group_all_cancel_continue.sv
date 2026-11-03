module tb_group_all_cancel_continue;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  int point;
  bw_mon_setup setup();
  bw_group_mon #(.GROUP_ID("g"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) g(.clk(clk),.reset_n(1'b1));
  initial begin
    point=register_point("p","controlled.p",BW_CYCLE,2,2);add_point_member("g","p");
    wait(monitor_ready);#250000;clk=1;#1;
    if(!scope_disabled(BW_GROUP,"g") || g.collector_running || !g.collector_cancelled || g.core.scheduler_running || !g.core.scheduler_cancelled)
      $fatal(1,"sole group workers did not actually exit their cancelled waits");
    #1000000;clk=0;#500000;clk=1;#1;
    if($time!=1750003 || group_batches["g"].expected!=1 || monitoring_failure_count!=1 || monitoring_shared_disabled)
      $fatal(1,"module testbench continuation or sticky disabled ingress differs");
    $display("TB_PASS group_all_cancel_continue failure_ticks=250001 continued_ticks=%0d workers_exited=1",$time);$finish;
  end
endmodule
