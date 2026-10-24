module tb_episode_final;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("episode.final"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(1),
    .FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("episode.none"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(1),
    .FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4)) idle
    (.clk(clk),.reset_n(1'b1),.valid(1'b0));
  initial begin
    wait(monitor_ready);
    #1000000;valid=1;clk=1;#1;clk=0;
    #999999;valid=0;clk=1;#1;clk=0;
    #999999;
    if (!point.episode_active || point.episode_result_seq!=0 || idle.episode_active || idle.episode_id!=0)
      $fatal(1,"observation ends before Q with one pending episode and no invented idle episode");
    $display("TB_PASS episode_final");$finish;
  end
endmodule
