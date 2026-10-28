module tb_group_startup_deadline;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bit owner_start=0,owner_second=0;
  int owner;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1),.EXPECTED_GROUP_COUNT(1),.STARTUP_TIMEOUT_NS(5)) setup();
  bw_point_mon #(.POINT_ID("p"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  always @(owner_start) if(owner_start)owner_second<=1;
  always @(owner_second) if(owner_second)
    owner=register_group_owner("g","component.owner",BW_NS,1,1);
  initial begin
    define_group("g",1);add_point_member("g","p");finish_configuration();
    #2000000;
    if(monitor_ready)$fatal(1,"complete points/configuration cannot substitute for a declared group owner");
    #3000000;owner_start<=1;
    #1;
    if(!monitor_ready || measurement_start_ticks!=5000000 || point.result_seq!=0)
      $fatal(1,"last owner arriving through deadline-slot NBA chain must participate before timeout");
    $display("TB_PASS group_startup_deadline");$finish;
  end
endmodule
