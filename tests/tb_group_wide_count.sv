module tb_group_wide_count;
  timeunit 1fs;timeprecision 1fs;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1),.EXPECTED_GROUP_COUNT(64'd4294967297),
    .STARTUP_TIMEOUT_NS(1)) setup();
  initial begin #2000000;$fatal(1,"expected core error did not occur");end
endmodule
