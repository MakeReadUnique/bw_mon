module tb_group_missing_ungrouped;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  int handle;
  bw_mon_setup setup();
  initial begin
    add_point_member("both","p0");add_point_member("both","p1");
    add_point_member("reuse","p0");
    handle=register_group_owner("both","component.both",BW_NS,1,1);
    handle=register_group_owner("reuse","component.reuse",BW_NS,1,1);
    handle=register_point("p0","component.p0",BW_NS,1,1);
    handle=register_point("p1","component.p1",BW_NS,1,1);
    // Direct member counts sum to3, but only2 unique points exist. The missing
    // ungrouped third point must still prevent ready.
    #6000000;$fatal(1,"expected core error did not occur");
  end
endmodule
