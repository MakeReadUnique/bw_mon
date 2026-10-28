module tb_report_cfg;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("cfg.bad"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(10),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) bad
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("cfg.good"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(10),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) good
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  initial begin
    bw_report_summary_t summary;
    int expected_warnings,expected_pass,expected_fail;
    expected_warnings=1;expected_pass=1;expected_fail=0;
    void'($value$plusargs("WARNINGS=%d",expected_warnings));
    void'($value$plusargs("PASSES=%d",expected_pass));
    void'($value$plusargs("FAILURES=%d",expected_fail));
    wait(monitor_ready);
    #1000000;valid=1;clk=1;#1;clk=0;
    #999999;valid=0;clk=1;#1;clk=0;
    #1000000;
    summary=check_report_summary();
    if(bad.episode_result.byte_count!=10 || good.episode_result.byte_count!=10 ||
       summary.pass_count!=expected_pass || summary.fail_count!=expected_fail ||
       summary.warning_count!=expected_warnings)
      $fatal(1,"cfg isolation mismatch pass=%0d fail=%0d warning=%0d expected=%0d/%0d/%0d",
        summary.pass_count,summary.fail_count,summary.warning_count,expected_pass,expected_fail,expected_warnings);
    $display("TB_PASS report_cfg continued=1");$finish;
  end
endmodule
