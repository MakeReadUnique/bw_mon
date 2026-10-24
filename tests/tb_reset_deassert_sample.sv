module tb_reset_deassert_sample;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, reset_n=0;
  logic dut_sampled_reset_n=0;
  int dut_transfers=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("deassert.ns"), .WINDOW_WIDTH(2), .UPDATE_STRIDE(1),
    .FIXED_BYTES(8)) point (.clk(clk), .reset_n(reset_n), .valid(1'b1));
  bw_point_mon #(.POINT_ID("deassert.cycle"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(2), .UPDATE_STRIDE(1), .FIXED_BYTES(8)) cycle_point
    (.clk(clk), .reset_n(reset_n), .valid(1'b1));
  // DUT-like sequential logic samples the old reset before an NBA release.
  always @(posedge clk) begin
    dut_sampled_reset_n<=reset_n;
    if (reset_n===1'b1) dut_transfers<=dut_transfers+1;
  end
  initial begin
    wait(monitor_ready);
    #1000000; clk=1; reset_n<=1;
    #1;
    if (dut_sampled_reset_n!==1'b0 || dut_transfers!=0 ||
        point.sampled_reset_n!==1'b0 || cycle_point.sampled_reset_n!==1'b0 ||
        point.raw_record.event_inc!=0 || point.raw_record.byte_inc!=0 ||
        cycle_point.raw_record.event_inc!=0 || cycle_point.raw_record.byte_inc!=0 ||
        point.total_bytes!=0 || cycle_point.total_bytes!=0 ||
        point.raw_control.reset_n!==1'b1)
      $fatal(1,"NBA reset deassertion must not invent a transfer absent from the DUT sample");
    clk=0;
    #999999; clk=1;
    #1;
    if (dut_sampled_reset_n!==1'b1 || dut_transfers!=1 ||
        point.raw_record.event_inc!=1 || point.raw_record.byte_inc!=8 ||
        cycle_point.raw_record.event_inc!=1 || point.total_bytes!=8 || cycle_point.total_bytes!=8)
      $fatal(1,"the next actually released edge must count normally");
    clk=0;
    #499999; reset_n=0;
    #500000; reset_n=1; clk=1;
    #1;
    if (dut_sampled_reset_n!==1'b1 || dut_transfers!=2 ||
        point.raw_record.event_inc!=1 || cycle_point.raw_record.event_inc!=1 ||
        point.total_bytes!=8 || cycle_point.total_bytes!=8 ||
        point.stats_epoch!=2 || cycle_point.stats_epoch!=2 ||
        point.raw_record.record_seq!=3 || point.raw_record.source_epoch!=2)
      $fatal(1,"active release before the edge must remain a definite new-epoch transfer");
    clk=0;
    #499999; reset_n=1'bx;
    #500000; clk=1; reset_n<=1;
    #1;
    if (dut_sampled_reset_n!==1'bx || dut_transfers!=2 ||
        point.sampled_reset_n!==1'bx || cycle_point.sampled_reset_n!==1'bx ||
        point.raw_record.event_inc!=0 || point.raw_record.bytes_complete ||
        point.raw_record.events_complete || cycle_point.raw_record.bytes_complete ||
        point.total_bytes!=8 || cycle_point.total_bytes!=8)
      $fatal(1,"NBA release from unknown must preserve the ambiguous edge sample");
    $display("TB_PASS reset_deassert_sample"); $finish;
  end
endmodule
