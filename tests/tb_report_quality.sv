module tb_report_quality;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0,reset_n=1;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("quality.zero"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(0),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) zero
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("quality.gap"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) gap
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(64'bx),.size_known(1'b0));
  bw_point_mon #(.POINT_ID("quality.truncated"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(16),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(100)) truncated
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("quality.reset"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(16),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) interrupted
    (.clk(clk),.reset_n(reset_n),.valid(valid));
  bw_point_mon #(.POINT_ID("quality.idle"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(0),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) idle
    (.clk(clk),.reset_n(1'b1),.valid(1'b0));
  initial begin
    bw_report_summary_t summary;
    wait(monitor_ready);
    #1000000;valid=1;clk=1;#1;clk=0;
    #499999;reset_n=0;
    #500000;valid=0;clk=1;#1;clk=0;
    #1000000;clk=1;#1;clk=0;
    #(5000003-$time);
    summary=check_report_summary();
    if(!zero.episode_result.e2e_valid || zero.episode_result.e2e_gbps!=0 ||
       zero.episode_result.event_count!=1 || gap.episode_result.e2e_valid ||
       !gap.window_valid || gap.episode_result.bytes_complete ||
       interrupted.episode_result.status!=BW_EPISODE_RESET_INTERRUPTED ||
       !truncated.episode_active || idle.episode_result_seq!=0 ||
       summary.pass_count!=1 || summary.fail_count!=0 || summary.warning_count!=5 || summary.finalized)
      $fatal(1,"zero/gap/reset/active/no-episode evidence must remain independent before finalization");
    $display("TB_PASS report_quality statistics_recovered_without_repairing_old_gap=1");$finish;
  end
endmodule
