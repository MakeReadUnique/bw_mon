module tb_checker_prefix;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1,known=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("checker.prefix"),.WINDOW_WIDTH(1),.DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_known(known),.size_bytes(64'd100));
  bw_group_mon #(.GROUP_ID("checker.prefix"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial add_point_member("checker.prefix","checker.prefix");
  initial begin
    bw_report_summary_t result;
    wait(monitor_ready);
    for(int update=1;update<=40;update++)begin
      valid=update<=24;known=update!=1 && !($test$plusargs("GAP") && update==21);
      #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
      #(measurement_start_ticks+update*1000000+1-$time);
      if(update==24 && $test$plusargs("TRUNCATED"))begin $display("TB_PASS checker_prefix truncated");$finish;end
    end
    result=check_report_summary();
    if(point.episode_result.bytes_complete || group_mon.episode_result.bytes_complete)
      $fatal(1,"unknown first transfer must keep whole episode byte evidence incomplete");
    if($test$plusargs("GAP"))begin
      if(result.pass_count!=0 || result.fail_count!=0 || result.warning_count!=2)
        $fatal(1,"a genuine gap inside the checked interval must still warn");
    end else begin
      if(!point.phase_result.bytes_complete || !group_mon.phase_result.bytes_complete ||
         point.phase_result.support_first_seq!=2 || point.phase_result.support_last_seq!=8 ||
         point.phase_result.start_ticks!=measurement_start_ticks+7000000 ||
         point.phase_result.end_ticks!=measurement_start_ticks+24500000 ||
         result.pass_count!=2 || result.fail_count!=0 || result.warning_count!=($test$plusargs("BW_EXPECT") ? 1 : 0))
        $fatal(1,"a fully observed later platform must PASS independently of earlier unknown bytes");
    end
    $display("TB_PASS checker_prefix");$finish;
  end
endmodule
