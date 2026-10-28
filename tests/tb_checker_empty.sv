module tb_checker_empty;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("shared.# bucket[2]"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  bw_group_mon #(.GROUP_ID("shared.# bucket[2]"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) group_mon
    (.clk(1'b0),.reset_n(1'b1));
  bw_point_mon #(.POINT_ID("disabled.\"quote\\#path"),.WINDOW_WIDTH(1)) disabled
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  initial add_point_member("shared.# bucket[2]","shared.# bucket[2]");
  initial begin
    bw_report_summary_t result;
    wait(monitor_ready);
    if($test$plusargs("IMMEDIATE"))begin $display("TB_PASS checker_empty immediate");$finish;end
    #1;
    result=check_report_summary();
    if(result.status!=BW_REPORT_STATISTICS_ONLY || result.warning_count!=0)
      $fatal(1,"normal waiting must not emit warnings before terminal settlement");
    $display("TB_PASS checker_empty");$finish;
  end
endmodule
