module auto_late_coarse_caller;
  timeunit 1ns; timeprecision 1fs;
  import bw_mon_pkg::*;
  initial begin
    #1fs;
    $display("coarse_caller_time=%0d",$time);
    add_point_member("late.group","late.point");
    $fatal(1,"expected core error did not occur");
  end
endmodule
module tb_auto_late_coarse;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  auto_late_coarse_caller caller();
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("late.point"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) point_mon
    (.clk(1'b0),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("late.group"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) group_mon
    (.clk(1'b0),.reset_n(1'b1));
  initial add_point_member("late.group","late.point");
endmodule
