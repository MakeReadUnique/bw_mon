module tb_reset_initial;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, reset_n=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("initial.reset"), .WINDOW_WIDTH(2), .UPDATE_STRIDE(1),
    .FIXED_BYTES(8)) point (.clk(clk), .reset_n(reset_n), .valid(1'b1));
  initial begin
    wait(monitor_ready); #1;
    if (point.stats_epoch!=1 || point.result_seq!=0 || point.denominator_valid ||
        point.raw_control.control_seq!=1 || point.raw_control.source_epoch!=1 ||
        point.raw_control.reset_n!==1'b0)
      $fatal(1,"known reset at ready must be applied exactly once");
    #999999; clk=1; #1; clk=0;
    if (point.raw_record.record_seq!=1 || point.raw_record.edge_index!=1 ||
        point.raw_record.byte_inc!=0 || point.accepted_record_seq!=1 || point.result_seq!=0)
      $fatal(1,"reset-held edges must still be recorded and accepted without advancing statistics");
    #999999; reset_n=1; clk=1; #1; clk=0;
    #1000000;
    if (point.stats_epoch!=1 || point.result_seq!=1 || point.window_bytes!=8 ||
        point.window_start_ticks!=2000001 || point.window_end_ticks!=3000001 ||
        point.raw_record.record_seq!=2 || point.raw_record.source_epoch!=1 ||
        point.raw_control.control_seq!=2 || point.total_bytes!=8)
      $fatal(1,"initial reset release must restart a fresh ns schedule and keep source identity/order");
    $display("TB_PASS reset_initial"); $finish;
  end
endmodule
