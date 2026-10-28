module tb_episode_config_error;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("episode.bad_q"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(1),
    .FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(0)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  initial begin #1000000;$fatal(1,"expected core error did not occur");end
endmodule
