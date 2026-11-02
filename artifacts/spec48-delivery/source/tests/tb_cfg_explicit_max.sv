module tb_cfg_explicit_max;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
`ifdef TEST_Q
  localparam bit Q=1;
`else
  localparam bit Q=0;
`endif
  bw_mon_setup setup();
  bw_point_mon #(.WINDOW_WIDTH(1),.UPDATE_STRIDE(Q ? 1 : 64'hffffffffffffffff),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(Q ? 64'hffffffffffffffff : 10)) point
    (.clk(1'b0),.reset_n(1'b1));
  initial begin #100;$fatal(1,"expected core error did not occur");end
endmodule
