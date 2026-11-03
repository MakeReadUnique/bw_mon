module tb_settle_typed_owners;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  // Reverse declaration order for the two equal-name pairs. All clocks stay
  // stopped: only the first statistics deadline creates new work.
  bw_group_mon #(.GROUP_ID("a"),.WINDOW_WIDTH(2))
    a_group(.clk(1'b0),.reset_n(1'b1));
  bw_point_mon #(.POINT_ID("a"),.WINDOW_WIDTH(2))
    a_point(.clk(1'b0),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("b"),.WINDOW_WIDTH(2))
    b_point(.clk(1'b0),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("b"),.WINDOW_WIDTH(2))
    b_group(.clk(1'b0),.reset_n(1'b1));
  bw_point_mon #(.POINT_ID("member"),.WINDOW_WIDTH(2))
    member(.clk(1'b0),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("a_parent"),.WINDOW_WIDTH(2))
    a_parent(.clk(1'b0),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("b_parent"),.WINDOW_WIDTH(2))
    b_parent(.clk(1'b0),.reset_n(1'b1));
  import "DPI-C" context function int bw_test_observe_group_completion();
  function void bw_test_group_completion_observed();
    if($time!=2000001 || monitoring_failure_count!=0 ||
       a_group.result_seq!=1 || b_group.result_seq!=1 ||
       a_point.result_seq!=1 || b_point.result_seq!=1 ||
       a_parent.result_seq!=1 || b_parent.result_seq!=1 ||
       !group_batch_complete("a") || !group_batch_complete("b") ||
       !group_batch_complete("a_parent") || !group_batch_complete("b_parent") ||
       !point_batch_complete("a") || !point_batch_complete("b"))
      $fatal(1,"equal-name owners must complete timer-only work at the original time");
    $display("TB_PASS settle_typed_owners original_ticks=%0d frames=0",$time);
    $finish;
  endfunction
  export "DPI-C" function bw_test_group_completion_observed;
  initial begin
    add_point_member("a","member");add_point_member("b","member");
    add_group_member("a_parent","a");add_group_member("b_parent","b");
    wait(monitor_ready);#2000000;
    if(!bw_test_observe_group_completion())$fatal(1,"cannot register timer-only verifier");
  end
endmodule
