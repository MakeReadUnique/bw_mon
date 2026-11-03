module tb_episode_final_budget;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("episode.final_budget"),.WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(4),.UPDATE_STRIDE(1),.FIXED_BYTES(8),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  initial begin
    wait(monitor_ready);#1000000;clk=1;#1;clk=0;
    #40000000000;$display("TB_PASS tb_episode_final_budget final-requested");$finish;
  end
endmodule
