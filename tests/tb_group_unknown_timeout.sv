module tb_group_unknown_timeout;
  timeunit 1fs;timeprecision 1fs;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1),.EXPECTED_GROUP_COUNT(1),
    .MISSING_RECORD_TIMEOUT_NS(64'hx000000000000001),.STARTUP_TIMEOUT_NS(1)) setup();
  initial begin #2000000;$fatal(1,"expected core error did not occur");end
endmodule
