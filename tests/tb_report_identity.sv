module tb_report_identity;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  bw_mon_setup setup();
  for(genvar i=0;i<1;i++) begin:gen_points
    bw_point_mon #(.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(10),
      .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) bw
      (.clk(clk),.reset_n(1'b1),.valid(valid));
  end
  bw_point_mon #(.POINT_ID("scope.# bucket[2]"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(10),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) explicit_id
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("scope.\"quote\\#path"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(10),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) escaped_id
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  initial begin
    bw_report_summary_t summary;
    wait(monitor_ready);
    #1000000;valid=1;clk=1;#1;clk=0;
    #999999;valid=0;clk=1;#1;clk=0;
    #1000000;summary=check_report_summary();
    if(gen_points[0].bw.scope_id!="tb_report_identity.gen_points[0].bw" ||
       escaped_id.scope_id!="scope.\"quote\\#path" ||
       summary.pass_count!=3 || summary.fail_count!=0 || summary.warning_count!=0)
      $fatal(1,"full default/quoted identities must match exactly, preserving brackets/hash/space");
    $display("TB_PASS report_identity");$finish;
  end
endmodule
