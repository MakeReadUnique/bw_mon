module tb_group_unknown_count;
  timeunit 1fs;timeprecision 1fs;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1),.EXPECTED_GROUP_COUNT(32'hx0000001),
    .STARTUP_TIMEOUT_NS(1)) setup();
  initial begin #2000000;$fatal(1,"expected core error did not occur");end
endmodule
