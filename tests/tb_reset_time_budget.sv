module tb_reset_time_budget;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, reset_n=1;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("global.budget"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(2), .UPDATE_STRIDE(1), .FIXED_BYTES(8)) point
    (.clk(clk), .reset_n(reset_n), .valid(1'b1));
  initial begin
    wait(monitor_ready);
    #39999000000; reset_n=0;
    #500000; reset_n=1;
    #1000000; clk=1;
    #1; $fatal(1,"expected core error did not occur");
  end
endmodule
