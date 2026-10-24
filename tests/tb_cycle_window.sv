module tb_cycle_window;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk = 0, valid = 0, reset_n = 1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("cycle.point"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(2), .UPDATE_STRIDE(1), .FIXED_BYTES(64)) cycle_mon
    (.clk(clk), .reset_n(reset_n), .valid(valid));
  bw_point_mon #(.POINT_ID("ns.point"), .WINDOW_BASIS(BW_NS),
    .WINDOW_WIDTH(2), .UPDATE_STRIDE(1), .FIXED_BYTES(64)) ns_mon
    (.clk(clk), .reset_n(reset_n), .valid(valid));

  task automatic sample(bw_u64_t at_ticks, bit transfer);
    #(at_ticks-$time-1);
    valid = transfer;
    #1; clk = 1;
    #1; clk = 0;
  endtask

  task automatic check_window(bw_u64_t seq, bw_u64_t left_cycle,
    bw_u64_t right_cycle, bw_u64_t left_ticks, bw_u64_t right_ticks,
    bw_u64_t known_bytes, bw_u64_t known_events, real gbps,
    real per_cycle, bit full);
    if (cycle_mon.result_seq != seq ||
        cycle_mon.window_start_cycle != left_cycle ||
        cycle_mon.window_end_cycle != right_cycle ||
        cycle_mon.coverage_cycles != right_cycle-left_cycle ||
        cycle_mon.window_start_ticks != left_ticks ||
        cycle_mon.window_end_ticks != right_ticks ||
        cycle_mon.coverage_ticks != right_ticks-left_ticks ||
        cycle_mon.window_bytes != known_bytes ||
        cycle_mon.window_events != known_events ||
        cycle_mon.window_full != full || cycle_mon.window_warmup == full ||
        !cycle_mon.bytes_complete || !cycle_mon.events_complete ||
        !cycle_mon.denominator_valid || cycle_mon.window_valid != full ||
        cycle_mon.member_reset_coverage)
      $fatal(1,"cycle interval/quality mismatch seq=%0d actual_seq=%0d bytes=%0d left=%0d right=%0d",
        seq, cycle_mon.result_seq, cycle_mon.window_bytes,
        cycle_mon.window_start_ticks, cycle_mon.window_end_ticks);
    if ($abs(cycle_mon.bandwidth_gbps-gbps) > 1e-10 ||
        $abs(cycle_mon.bytes_per_cycle-per_cycle) > 1e-10)
      $fatal(1,"cycle bandwidth mismatch expected=%0.15f actual=%0.15f B/cycle=%0.15f",
        gbps, cycle_mon.bandwidth_gbps, cycle_mon.bytes_per_cycle);
  endtask

  // Independent actual-edge table (ns / valid): .25/1, .75/1, 1.25/0,
  // 2.25/1, 12.25/1, 12.75/0, 13.25/0, 13.75/0. Each transfer is 64 B.
  initial begin
    wait(monitor_ready);
    #1;
    if (cycle_mon.result_seq != 0 || cycle_mon.coverage_cycles != 0 ||
        cycle_mon.coverage_ticks != 0 || cycle_mon.denominator_valid)
      $fatal(1,"initial zero-coverage snapshot is invalid");
    sample(250000,1);
    if (cycle_mon.result_seq != 0 || cycle_mon.denominator_valid ||
        cycle_mon.total_bytes != 64 || cycle_mon.total_events != 1)
      $fatal(1,"first edge starts a cycle without fabricating a completed cycle");
    sample(750000,1);
    check_window(1,1,2,250000,750000,64,1,128.0,64.0,0);
    sample(1250000,0);
    check_window(2,1,3,250000,1250000,128,2,128.0,64.0,1);
    sample(2250000,1);
    check_window(3,2,4,750000,2250000,64,1,42.666666666666667,32.0,1);
    #(12000001-$time);
    check_window(3,2,4,750000,2250000,64,1,42.666666666666667,32.0,1);
    if (ns_mon.result_seq != 12 || ns_mon.window_end_ticks != 12000000 ||
        ns_mon.window_bytes != 0 || ns_mon.bandwidth_gbps != 0.0 || !ns_mon.window_valid)
      $fatal(1,"ns windows must continue and expire while cycle snapshot holds");
    sample(12250000,1);
    check_window(4,3,5,1250000,12250000,64,1,5.818181818181818,32.0,1);
    sample(12750000,0);
    check_window(5,4,6,2250000,12750000,128,2,12.190476190476190,64.0,1);
    sample(13250000,0);
    check_window(6,5,7,12250000,13250000,64,1,64.0,32.0,1);
    sample(13750000,0);
    check_window(7,6,8,12750000,13750000,0,0,0.0,0.0,1);
    if (cycle_mon.total_bytes != 256 || cycle_mon.total_events != 4)
      $fatal(1,"raw cumulative increments must count each event once");
    $display("TB_PASS cycle_window");
    $finish;
  end
endmodule
