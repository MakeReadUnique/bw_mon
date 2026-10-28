module tb_point_historical_fail;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,vp=0,vq=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("damaged"),.WINDOW_WIDTH(1),.FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1))
    p(.clk(clk),.reset_n(1'b1),.valid(vp));
  bw_point_mon #(.POINT_ID("healthy"),.WINDOW_WIDTH(1),.FIXED_BYTES(16),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1))
    q(.clk(clk),.reset_n(1'b1),.valid(vq));
  // Its ID deliberately equals the independent point's ID. Typed ownership
  // must leave this healthy aggregation scope intact after point disable.
  bw_group_mon #(.GROUP_ID("damaged"),.WINDOW_WIDTH(1))
    g(.clk(clk),.reset_n(1'b1));
  initial begin
    bw_report_summary_t summary;
    bw_u64_t retained_counter;
    add_point_member("damaged","healthy");wait(monitor_ready);
    #1000000;vp=1;clk=1;#1;clk=0;
    #999999;vp=0;clk=1;#1;clk=0;
    #1000000;
    summary=check_report_summary();
    if(summary.fail_count!=1)$fatal(1,"reliable earlier 8GB/s episode must fail independent 9GB/s minimum");
    if($test$plusargs("SHARED_ARITHMETIC"))begin
      retained_counter=checked_add(BW_U64_MAX,1,"shared.counter");
      summary=check_report_summary();
      if(retained_counter!=BW_U64_MAX || !monitoring_shared_disabled || summary.fail_count!=1 || summary.pass_count!=0)
        $fatal(1,"shared arithmetic rejection must preserve old counters and historical FAIL");
      $display("TB_PASS point_historical_shared_arithmetic retained_fail=1 retained_counter=18446744073709551615");$finish;
    end
    inject_growth_failure("damaged","recorder.samples");
    #999999;vq=1;clk=1;#1;clk=0;
    #999999;vq=0;clk=1;#1;clk=0;
    #1000000;
    summary=check_report_summary();
    if(summary.fail_count!=1 || summary.pass_count!=1 || summary.status!=BW_REPORT_FAIL ||
       !scope_disabled(BW_POINT,"damaged") || scope_disabled(BW_POINT,"healthy") || scope_disabled(BW_GROUP,"damaged"))
      $fatal(1,"disable must retain historical FAIL, admit healthy later PASS, and preserve typed same-name group");
    $display("TB_PASS point_historical_fail retained_fail=1 later_pass=1 typed_group_healthy=1");$finish;
  end
endmodule
