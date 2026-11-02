module tb_report_e2e;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=152;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("tb.raw[0].bw"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(1),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes),.size_known(1'b1));
  initial begin
    bw_report_summary_t summary;
    bw_u64_t total;
    int warnings;
    string expected;
    total=15200;expected="PASS";warnings=0;
    void'($value$plusargs("TOTAL=%d",total));
    void'($value$plusargs("EXPECTED=%s",expected));
    void'($value$plusargs("WARNINGS=%d",warnings));
    wait(monitor_ready);
    for(int t=1;t<=101;t++) begin
      #(ns_to_ticks(t)-$time);valid=t<=100;
      bytes=total/100+(t<=total%100 ? 1 : 0);clk=1;
      #1;clk=0;
    end
    #(103000003-$time);
    summary=check_report_summary();
    if(point.episode_result.byte_count!=total || point.episode_result.duration_ticks!=100000000 ||
       !point.episode_result.e2e_valid || $abs(point.episode_result.e2e_gbps-real'(total)/100.0)>1e-10 ||
       summary.pass_count!=int'(expected=="PASS")+int'(total>0) || summary.fail_count!=(expected=="FAIL") ||
       summary.warning_count!=warnings+int'(total==0))
      $fatal(1,"raw 100ns byte-table result/check mismatch total=%0d expected=%s actual=%.17g pass=%0d fail=%0d warning=%0d",
        total,expected,point.episode_result.e2e_gbps,summary.pass_count,summary.fail_count,summary.warning_count);
    $display("TB_PASS report_e2e total=%0d expected=%s continued_after_comparison=1",total,expected);$finish;
  end
endmodule
