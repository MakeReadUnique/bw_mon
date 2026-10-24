module tb_reset_cycle_unknown;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, reset_n=1, valid=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("cycle.reset.gap"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(2), .UPDATE_STRIDE(1), .FIXED_BYTES(8)) point
    (.clk(clk), .reset_n(reset_n), .valid(valid));
  task automatic sample(bw_u64_t ticks, bit transfer);
    #(ticks-$time-1); valid=transfer;
    #1; clk=1;
    #1; clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    sample(250000,1); sample(750000,1); sample(1250000,1);
    #(2000000-$time); reset_n=1'bz;
    #1000000; reset_n=1;
    #500001;
    if (point.result_seq!=2 || point.window_start_ticks!=250000 ||
        point.window_end_ticks!=1250000 || point.window_bytes!=16 || !point.bytes_complete ||
        !point.events_complete || !point.window_valid || point.raw_record.record_seq!=3)
      $fatal(1,"cycle stop must hold the published snapshot while reset quality changes separately");
    sample(3750000,1);
    if (point.result_seq!=3 || point.window_start_cycle!=2 || point.window_end_cycle!=4 ||
        point.window_bytes!=16 || point.bytes_complete || point.events_complete ||
        point.window_valid || !point.window_full ||
        $abs(point.bandwidth_gbps-5.333333333333333)>1e-10)
      $fatal(1,"resumed cycle window must include the no-edge unknown reset interval");
    sample(4250000,0);
    if (point.bytes_complete || point.window_bytes!=16)
      $fatal(1,"unknown interval must remain until its physical range leaves the cycle window");
    sample(4750000,0);
    if (!point.bytes_complete || !point.events_complete || !point.window_valid ||
        point.window_bytes!=8 || point.stats_epoch!=0 || point.raw_record.source_epoch!=0 ||
        point.raw_control.control_seq!=3 || $abs(point.bandwidth_gbps-8.0)>1e-10)
      $fatal(1,"cycle quality must recover exactly without a fabricated reset or sampling edge");
    $display("TB_PASS reset_cycle_unknown"); $finish;
  end
endmodule
