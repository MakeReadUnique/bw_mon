module tb_checker_history;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=100;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("checker.history"),.WINDOW_WIDTH(1),.DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_known(1'b1),.size_bytes(bytes));
  bw_group_mon #(.GROUP_ID("checker.history"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial add_point_member("checker.history","checker.history");
  initial begin
    bw_report_summary_t result;
    wait(monitor_ready);
    for(int update=1;update<=80;update++)begin
      valid=update<=24 || (update>=41 && update<=64);
      bytes=update<=24 ? (update%2 ? 92 : 108) : 100;
      #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
      #(measurement_start_ticks+update*1000000+1-$time);
      if(update==40)begin
        result=check_report_summary();
        if(result.fail_count!=2 || result.pass_count!=0 || result.warning_count!=0)
          $fatal(1,"first real point/group episode must retain its two default FAILs");
      end
    end
    result=check_report_summary();
    if(result.status!=BW_REPORT_FAIL || result.fail_count!=2 || result.pass_count!=2 || result.warning_count!=0)
      $fatal(1,"later real constant episode PASS must not clear earlier typed-scope FAILs");
    $display("TB_PASS checker_history");$finish;
  end
endmodule
