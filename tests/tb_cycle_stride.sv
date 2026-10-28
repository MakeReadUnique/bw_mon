module tb_cycle_stride;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, valid=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("sliding"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(5), .UPDATE_STRIDE(3), .FIXED_BYTES(64)) sliding
    (.clk(clk), .reset_n(1'b1), .valid(valid));
  bw_point_mon #(.POINT_ID("blocks"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(3), .UPDATE_STRIDE(3), .FIXED_BYTES(64)) blocks
    (.clk(clk), .reset_n(1'b1), .valid(valid));

  task automatic pulse(bit transfer);
    valid=transfer;
    #250000; clk=1;
    #1; clk=0;
    #249999;
  endtask

  // Clock edges .25,.75,1.25,... ns. Transfers on edges 1,2,4,5,7.
  // The expected intervals and byte counts below are hand-counted from them.
  initial begin
    wait(monitor_ready);
    pulse(1); pulse(1); pulse(0); pulse(1);
    if (sliding.result_seq!=1 || sliding.window_start_cycle!=1 ||
        sliding.window_end_cycle!=4 || sliding.coverage_cycles!=3 ||
        sliding.window_start_ticks!=250001 || sliding.window_end_ticks!=1750001 ||
        sliding.window_bytes!=128 || sliding.window_events!=2 ||
        !sliding.window_warmup || sliding.window_full ||
        $abs(sliding.bandwidth_gbps-85.333333333333333)>1e-10 ||
        $abs(sliding.bytes_per_cycle-42.666666666666667)>1e-10)
      $fatal(1,"W5/S3 first warmup must cover three actual cycles");
    if (blocks.result_seq!=1 || !blocks.window_full || blocks.window_bytes!=128 ||
        blocks.window_start_cycle!=1 || blocks.window_end_cycle!=4)
      $fatal(1,"S=W first block must exclude edge 4's new event");
    pulse(1); pulse(0);
    if (sliding.result_seq!=1 || sliding.window_full || sliding.window_end_cycle!=4)
      $fatal(1,"reaching W must not insert an unscheduled publication");
    pulse(1);
    if (sliding.result_seq!=2 || !sliding.window_full || sliding.window_warmup ||
        sliding.window_start_cycle!=2 || sliding.window_end_cycle!=7 ||
        sliding.coverage_cycles!=5 || sliding.window_start_ticks!=750001 ||
        sliding.window_end_ticks!=3250001 || sliding.window_bytes!=192 ||
        sliding.window_events!=3 || $abs(sliding.bandwidth_gbps-76.8)>1e-10 ||
        $abs(sliding.bytes_per_cycle-38.4)>1e-10)
      $fatal(1,"W5/S3 first full result must be the scheduled [2,7) window");
    if (blocks.result_seq!=2 || blocks.window_start_cycle!=4 ||
        blocks.window_end_cycle!=7 || blocks.window_bytes!=128 ||
        $abs(blocks.bytes_per_cycle-42.666666666666667)>1e-10)
      $fatal(1,"S=W second block must include edge 4 and exclude edge 7");
    pulse(0); pulse(0); pulse(0);
    if (sliding.result_seq!=3 || sliding.window_start_cycle!=5 ||
        sliding.window_end_cycle!=10 || sliding.window_start_ticks!=2250001 ||
        sliding.window_end_ticks!=4750001 || sliding.window_bytes!=128 ||
        $abs(sliding.bandwidth_gbps-51.2)>1e-10 ||
        $abs(sliding.bytes_per_cycle-25.6)>1e-10)
      $fatal(1,"later exact sliding boundary or denominator incorrect");
    if (blocks.result_seq!=3 || blocks.window_start_cycle!=7 ||
        blocks.window_end_cycle!=10 || blocks.window_bytes!=64 ||
        $abs(blocks.bandwidth_gbps-42.666666666666667)>1e-10)
      $fatal(1,"S=W third block must contain edge 7 exactly once");
    if (sliding.total_bytes!=320 || blocks.total_bytes!=320 ||
        sliding.total_events!=5 || blocks.total_events!=5)
      $fatal(1,"window publication must not change raw cumulative accounting");
    $display("TB_PASS cycle_stride");
    $finish;
  end
endmodule
