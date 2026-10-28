module tb_group_wide_count;
  timeunit 1fs;timeprecision 1fs;
  bw_mon_setup setup();
  initial begin #2000000;$fatal(1,"expected core error did not occur");end
endmodule
