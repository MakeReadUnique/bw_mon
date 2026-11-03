module tb_reset_same_time;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, reset_n=1, valid=1;
  bit drive_reset=0, watch_publication=0;
  int mode=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("same.time"), .WINDOW_WIDTH(2), .UPDATE_STRIDE(1),
    .FIXED_BYTES(8)) point (.clk(clk), .reset_n(reset_n), .valid(valid));
  bw_point_mon #(.POINT_ID("same.time.cycle"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(2), .UPDATE_STRIDE(1), .FIXED_BYTES(8)) cycle_point
    (.clk(clk), .reset_n(reset_n), .valid(valid));
  always @(drive_reset) if (drive_reset) reset_n<=0;
  always @(point.result_seq)
    if (watch_publication && $time==measurement_start_ticks+2000000 && point.result_seq!=1)
      $fatal(1,"reset T must not transiently publish an old-epoch window");
  always @(cycle_point.result_seq)
    if (watch_publication && $time==measurement_start_ticks+2000000 && cycle_point.result_seq!=1)
      $fatal(1,"reset T must not transiently publish an old-epoch cycle window");
  initial begin
    void'($value$plusargs("MODE=%d",mode));
    wait(monitor_ready);
    #250000; clk=1; #1; clk=0;
    #499999; clk=1; #1; clk=0;
    #749999; watch_publication=1;
    #500000;
    case (mode)
      0: begin reset_n=0; clk=1; end
      1: begin clk=1; reset_n=0; end
      2: begin clk=1; reset_n<=0; end
      3: begin clk<=1; drive_reset<=1; end
    endcase
    #1;
    if (point.stats_epoch!=1 || point.result_seq!=1 || point.total_bytes!=0 ||
        point.window_bytes!=0 || point.denominator_valid || point.accepted_record_seq!=3 ||
        cycle_point.stats_epoch!=1 || cycle_point.result_seq!=1 ||
        cycle_point.total_bytes!=0 || cycle_point.accepted_record_seq!=3 ||
        cycle_point.denominator_valid)
      $fatal(1,"same-time own reset must precede frame/timer processing");
    if (point.raw_record.record_seq!=3 || point.raw_record.edge_index!=3 ||
        point.raw_record.timestamp_ticks!=measurement_start_ticks+2000000 || point.raw_record.source_epoch!=1 ||
        point.raw_record.event_inc!=0 || point.raw_record.byte_inc!=0 ||
        point.raw_record.reset_points!=1 || point.raw_record.reset_n!==1'b0 ||
        !point.raw_record.bytes_complete || !point.raw_record.events_complete)
      $fatal(1,"same-time point reset must also suppress its upward raw increment");
    if (point.raw_control.control_seq!=2 || point.raw_control.timestamp_ticks!=measurement_start_ticks+2000000 ||
        point.raw_control.source_epoch!=1 || point.raw_control.reset_n!==1'b0)
      $fatal(1,"reset control must be distinct and carry its original timestamp/epoch");
    clk=0;
    #(measurement_start_ticks+3000000-$time); reset_n<=1; clk<=1;
    #1;
    if (point.raw_record.record_seq!=4 || point.total_bytes!=8 || point.result_seq!=1 ||
        point.raw_control.control_seq!=3 || point.raw_record.source_epoch!=1 ||
        cycle_point.result_seq!=1 || cycle_point.total_bytes!=8)
      $fatal(1,"release at an actual edge must accept the known new transfer without resetting source order");
    clk=0;
    #(measurement_start_ticks+4000000-$time); clk=1;
    #1;
    if (point.result_seq!=2 || point.window_start_ticks!=measurement_start_ticks+3000000 ||
        point.window_end_ticks!=measurement_start_ticks+4000000 || point.window_bytes!=8 ||
        point.window_events!=1 || point.total_bytes!=16 || point.accepted_record_seq!=5 ||
        $abs(point.bandwidth_gbps-8.0)>1e-10 || !point.window_warmup ||
        cycle_point.result_seq!=2 || cycle_point.window_start_cycle!=4 ||
        cycle_point.window_end_cycle!=5 || cycle_point.window_bytes!=8 ||
        cycle_point.accepted_record_seq!=5 || !cycle_point.window_warmup)
      $fatal(1,"timer-first/new-frame ordering must preserve right exclusion and later metadata");
    $display("TB_PASS reset_same_time mode=%0d",mode); $finish;
  end
endmodule
