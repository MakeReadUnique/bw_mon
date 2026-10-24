module tb_credit_config_error;
  timeunit 1ns;timeprecision 1fs;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(bw_mon_pkg::BW_CREDIT),.CREDIT_ENABLE(1),
    .WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) point(.clk(1'b0),.reset_n(1'b1));
  initial begin #1ns;$fatal(1,"expected core error did not occur");end
endmodule
