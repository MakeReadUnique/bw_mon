module tb_group_wide;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("p0"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(64'hffffffff)) p0
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("p1"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(64'hffffffff)) p1
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("wide"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial begin
    add_point_member("wide","p0");add_point_member("wide","p1");
    wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    if(group_mon.raw_record.byte_inc!=64'd8589934590 || group_mon.raw_record.event_inc!=2)
      $fatal(1,"group per-edge increment must not truncate to a single-point32-bit amount");
    #750000;
    if(group_mon.window_bytes!=64'd8589934590 || group_mon.total_bytes!=64'd8589934590 ||
       !group_mon.window_valid || $abs(group_mon.bandwidth_gbps-8589934590.0)>1e-5)
      $fatal(1,"wide exact group bytes must survive transport, storage and public bandwidth calculation");
    $display("TB_PASS group_wide");$finish;
  end
endmodule
