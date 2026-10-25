module tb_storage_failure;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1),.EXPECTED_GROUP_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("fault.point"),.FIXED_BYTES(8),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) point_mon
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("fault.group"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial begin
    define_group("fault.group",1);add_point_member("fault.group","fault.point");
    inject_growth_failure("fault.point","history.events");
    finish_configuration();wait(monitor_ready);
    #250000;clk=1;#1;$fatal(1,"expected core error did not occur");
  end
endmodule
