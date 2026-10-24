module tb_reset_rewarm;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, reset_n=1, valid=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("reset.ns"), .WINDOW_WIDTH(4), .UPDATE_STRIDE(1),
    .FIXED_BYTES(8)) ns_point (.clk(clk), .reset_n(reset_n), .valid(valid));
  bw_point_mon #(.POINT_ID("reset.cycle"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(2), .UPDATE_STRIDE(1), .FIXED_BYTES(8)) cycle_point
    (.clk(clk), .reset_n(reset_n), .valid(valid));

  task automatic sample(bw_u64_t at_ticks, bit transfer);
    #(at_ticks-$time-1); valid=transfer;
    #1; clk=1;
    #1; clk=0;
  endtask

  initial begin
    wait(monitor_ready);
    sample(250000,1); sample(750000,1); sample(1250000,1);
    #(2500000-$time); reset_n=0;
    #1;
    if (ns_point.stats_epoch!=1 || cycle_point.stats_epoch!=1 ||
        ns_point.total_bytes!=0 || cycle_point.total_bytes!=0 ||
        ns_point.window_bytes!=0 || cycle_point.window_bytes!=0 ||
        ns_point.denominator_valid || cycle_point.denominator_valid ||
        !ns_point.window_warmup || !cycle_point.window_warmup)
      $fatal(1,"no-edge reset must clear only local statistics and advance the epoch");
    if (ns_point.raw_record.record_seq!=3 || cycle_point.raw_record.edge_index!=3)
      $fatal(1,"no-edge reset must not fabricate source frames or cycles");
    #(4500000-$time); reset_n=1;
    #1;
    if (ns_point.stats_epoch!=1 || cycle_point.stats_epoch!=1 ||
        ns_point.result_seq!=2 || cycle_point.result_seq!=2 ||
        ns_point.raw_record.record_seq!=3 || cycle_point.raw_record.edge_index!=3)
      $fatal(1,"reset release must preserve identities and all source/publication sequences");
    sample(4750000,1);
    if (cycle_point.result_seq!=2 || cycle_point.denominator_valid ||
        ns_point.raw_record.record_seq!=4 || ns_point.raw_record.edge_index!=4 ||
        ns_point.raw_record.source_epoch!=1 || cycle_point.raw_record.source_epoch!=1)
      $fatal(1,"first post-reset frame must retain transport order and start fresh cycle coverage");
    #(5000001-$time);
    if (ns_point.result_seq!=2)
      $fatal(1,"ns reset release must restart the schedule at release+S, not the global phase");
    sample(5250000,0);
    if (cycle_point.result_seq!=3 || cycle_point.window_start_cycle!=4 ||
        cycle_point.window_end_cycle!=5 || cycle_point.coverage_cycles!=1 ||
        cycle_point.window_bytes!=8 || !cycle_point.window_warmup ||
        $abs(cycle_point.bandwidth_gbps-16.0)>1e-10)
      $fatal(1,"post-reset cycle warmup must use one actual complete cycle");
    sample(5750000,1);
    if (cycle_point.result_seq!=4 || !cycle_point.window_full ||
        cycle_point.window_start_cycle!=4 || cycle_point.window_end_cycle!=6 ||
        cycle_point.window_bytes!=8 || $abs(cycle_point.bandwidth_gbps-8.0)>1e-10 ||
        $abs(cycle_point.bytes_per_cycle-4.0)>1e-10)
      $fatal(1,"post-reset full cycle window has incorrect boundaries/counting");
    if (ns_point.result_seq!=3 || ns_point.window_start_ticks!=4500000 ||
        ns_point.window_end_ticks!=5500000 || ns_point.coverage_ticks!=1000000 ||
        ns_point.window_bytes!=8 || !ns_point.bytes_complete || !ns_point.denominator_valid ||
        ns_point.window_full || !ns_point.window_warmup ||
        $abs(ns_point.bandwidth_gbps-8.0)>1e-10)
      $fatal(1,"post-reset ns warmup must use actual coverage from release");
    if (ns_point.total_bytes!=16 || cycle_point.total_bytes!=16 ||
        ns_point.raw_record.record_seq!=6 || ns_point.raw_record.edge_index!=6 ||
        ns_point.scope_id!="reset.ns" || cycle_point.scope_id!="reset.cycle" ||
        measurement_start_ticks!=0)
      $fatal(1,"local reset must not alter registration/global time or rewind source order");
    $display("TB_PASS reset_rewarm"); $finish;
  end
endmodule
