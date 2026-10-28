module tb_checker_disabled;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=100;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("checker.disabled"),.WINDOW_WIDTH(1),.DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) failed_point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_known(1'b1),.size_bytes(bytes));
  bw_point_mon #(.POINT_ID("checker.healthy"),.WINDOW_WIDTH(1),.FIXED_BYTES(100),.EPISODE_ENABLE(1)) healthy_point
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_group_mon #(.GROUP_ID("checker.disabled"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) same_id_group
    (.clk(clk),.reset_n(1'b1));
  initial add_point_member("checker.disabled","checker.healthy");
  initial begin
    bw_report_summary_t result;
    wait(monitor_ready);
    for(int update=1;update<=80;update++)begin
      valid=update<=24 || (update>=41 && update<=64);
      bytes=update%2 ? 92 : 108;
      if(update==55)inject_growth_failure(scope_key(BW_POINT,"checker.disabled"),
        $test$plusargs("PHASE_FAULT") ? "default.phases" : "default.raw");
      #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
      #(measurement_start_ticks+update*1000000+1-$time);
      if(update==40)begin
        result=check_report_summary();
        if(result.fail_count!=1 || result.pass_count!=2 || result.warning_count!=0)
          $fatal(1,"first trusted episode must settle before a later monitoring failure");
      end
      if(update==($test$plusargs("PHASE_FAULT") ? 76 : 56) && (!scope_disabled(BW_POINT,"checker.disabled") ||
          scope_disabled(BW_GROUP,"checker.disabled") || scope_disabled(BW_POINT,"checker.healthy") ||
          monitoring_root_cause[scope_key(BW_POINT,"checker.disabled")]!=scope_key(BW_POINT,"checker.disabled")))
        $fatal(1,"checker storage failure must preserve typed ownership and unrelated same-ID group");
    end
    result=check_report_summary();
    if(result.status!=BW_REPORT_FAIL || result.fail_count!=1 || result.pass_count!=4 || result.warning_count!=0)
      $fatal(1,"healthy scopes must continue default checks and historical FAIL must survive disable");
    $display("TB_PASS checker_disabled");$finish;
  end
endmodule
