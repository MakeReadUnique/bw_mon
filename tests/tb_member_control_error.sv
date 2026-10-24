module tb_member_control_error;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_control_t control;
  bit control_toggle=0;
  int handle;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_stats_core #(.WINDOW_WIDTH(2), .UPDATE_STRIDE(1)) core
    (.scope_id("control.scope"), .record('0), .record_toggle(1'b0),
     .member_control(control), .member_control_toggle(control_toggle));
  initial begin
    handle=register_point("origin.point","tb_member_control_error",BW_NS,2,1,"clk");
    wait(monitor_ready);
    #1000000;
    control='0;
    control.timestamp_ticks=$time; control.point_handle=handle;
    control.control_seq=1; control.reset_n=1;
    control_toggle<=!control_toggle;
    #1000000;
    control.timestamp_ticks=$time;
    control_toggle<=!control_toggle;
    #1; $fatal(1,"expected core error did not occur");
  end
endmodule
