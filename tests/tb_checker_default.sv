module tb_checker_default;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1,reset_n=1,known=1;
  logic [63:0] bytes=100;
  bw_mon_setup setup();
  for(genvar m=0;m<4;m++)begin:members
    bw_point_mon #(.POINT_ID($sformatf("checker.p%0d",m)),.WINDOW_WIDTH(1),.DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
      (.clk(clk),.reset_n(reset_n),.valid(valid),.size_known(known),.size_bytes(bytes));
    initial add_point_member("checker.group",$sformatf("checker.p%0d",m));
  end
  bw_group_mon #(.GROUP_ID("checker.group"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) group_mon
    (.clk(clk),.reset_n(reset_n));
  initial begin
    bw_report_summary_t result;
    wait(monitor_ready);
    for(int update=1;update<=40;update++)begin
      valid=update<=24;
      known=!($test$plusargs("GAP") && update==21);
      bytes=$test$plusargs("ALTERNATE") ? ((update%2) ? 92 : 108) : 100;
      #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
      #(measurement_start_ticks+update*1000000+1-$time);
      if(update==24 && $test$plusargs("RESET"))reset_n=0;
      if(update==24 && $test$plusargs("TRUNCATED"))begin $display("TB_PASS checker_default truncated");$finish;end
      if(update>=7 && update<=24 && !$test$plusargs("RESET") &&
         !($test$plusargs("GAP") && update>=21) && (members[0].point.phase_current!=BW_PHASE_STEADY ||
         group_mon.phase_current!=BW_PHASE_STEADY || members[0].point.phase_id!=1 || group_mon.phase_id!=1))
        $fatal(1,"constant and alternating raw inputs must retain one real STEADY platform");
    end
    if(members[0].point.phase_result.support_first_seq!=1 ||
       members[0].point.phase_result.support_last_seq!=7 || members[0].point.phase_result.support_count!=7 ||
       members[0].point.phase_result.support_min_gbps!=($test$plusargs("ALTERNATE") ? 92 : 100) ||
       members[0].point.phase_result.support_max_gbps!=($test$plusargs("ALTERNATE") ? 108 : 100))
      $fatal(1,"original seven recognition rows must survive fit ring advance and final delivery");
    result=check_report_summary();
    if($test$plusargs("ALTERNATE"))begin
      if(result.fail_count!=5 || result.pass_count!=($test$plusargs("BW_EXPECT") ? 3 : 0) || result.warning_count!=0)
        $fatal(1,"every real point/group platform must FAIL sustained alternating eight percent");
    end else if(result.pass_count!=5 || result.fail_count!=0 || result.warning_count!=0)
      $fatal(1,"every real constant point/group platform must PASS without BW_EXPECT");
    $display("TB_PASS checker_default");$finish;
  end
endmodule
