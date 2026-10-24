module tb_reset_unknown;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, reset_n=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("reset.unknown"), .WINDOW_WIDTH(2), .UPDATE_STRIDE(1),
    .FIXED_BYTES(8)) point (.clk(clk), .reset_n(reset_n), .valid(1'b1));
  initial begin
    wait(monitor_ready);
    #250000; clk=1; #1; clk=0;
    #249999; reset_n=1'bx;
    #500001;
    if (point.window_bytes!=8 || point.window_events!=1 || point.bytes_complete ||
        point.events_complete || point.stats_epoch!=0 || !point.window_warmup ||
        !point.denominator_valid || point.member_reset_coverage)
      $fatal(1,"unknown no-edge reset interval must preserve known bytes and mark a gap");
    #499999; reset_n=1;
    #500001;
    if (point.window_bytes!=8 || point.bytes_complete || !point.window_full ||
        point.window_valid || point.stats_epoch!=0)
      $fatal(1,"reset recovery must not erase an unknown interval still in the window");
    #1000000;
    if (point.window_bytes!=0 || point.bytes_complete || point.events_complete)
      $fatal(1,"unknown [0.5,1.5) must still overlap the [1,3) window");
    #1000000;
    if (point.window_bytes!=0 || !point.bytes_complete || !point.events_complete ||
        !point.window_valid || point.raw_record.record_seq!=1 || point.raw_record.edge_index!=1 ||
        point.raw_control.control_seq!=3 || point.raw_control.source_epoch!=0)
      $fatal(1,"unknown interval must expire exactly without inventing frames or resetting epochs");
    $display("TB_PASS reset_unknown"); $finish;
  end
endmodule
