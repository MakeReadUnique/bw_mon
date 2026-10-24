module bw_test_bus(input logic clk, input logic valid);
endmodule
bind bw_test_bus bw_point_mon #(.WINDOW_WIDTH(10), .UPDATE_STRIDE(1), .FIXED_BYTES(64)) bw
  (.clk(clk), .reset_n(1'b1), .valid(valid));

module tb_ns_bind;
  timeunit 1ns; timeprecision 1fs;
  logic clk = 0, valid0 = 0, valid1 = 0;
  bw_test_bus p0(clk, valid0), p1(clk, valid1);
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  task automatic transfer(input time delay_ticks);
    #(delay_ticks * 1fs); valid0 = 1;
    #1fs; clk = 1;
    #1fs; clk = 0; valid0 = 0;
  endtask
  task automatic check(input longint unsigned bytes0, input real gbps0,
                       input longint unsigned end_ticks);
    #1fs;
    if (p0.bw.window_bytes !== bytes0 || p0.bw.window_end_ticks !== end_ticks)
      $fatal(1,"known event table: bytes=%0d expected=%0d end=%0d expected=%0d",
             p0.bw.window_bytes,bytes0,p0.bw.window_end_ticks,end_ticks);
    if ($abs(p0.bw.bandwidth_gbps-gbps0)>1e-10)
      $fatal(1,"bandwidth=%0.12f expected=%0.12f",p0.bw.bandwidth_gbps,gbps0);
    if (!p0.bw.window_full || !p0.bw.bytes_complete || !p0.bw.denominator_valid)
      $fatal(1,"full known window quality incorrect");
    if (p1.bw.window_bytes !== 0 || p1.bw.total_bytes !== 0)
      $fatal(1,"independent empty point contaminated");
  endtask
  initial begin
    wait (bw_mon_pkg::monitor_ready);
    if (p0.bw.scope_id != "tb_ns_bind.p0.bw" || p1.bw.scope_id != "tb_ns_bind.p1.bw")
      $fatal(1,"default Point ID must be public monitor hierarchy");
    if (p0.bw.denominator_valid || p0.bw.result_seq != 0)
      $fatal(1,"zero coverage must be invalid, unpublished");
    fork
      begin
        transfer(999999); // 1 ns
        transfer(1499998); // 2.5 ns, preserves sub-ns timestamp
        transfer(7499998); // 10 ns: excluded from [0,10)
      end
      begin
        #10ns; check(128,12.8,10000000);
        #999999fs; check(192,19.2,11000000); // includes left endpoint 1 ns
        #999999fs; check(128,12.8,12000000); // expires 1 ns
        #10999999fs; check(0,0.0,23000000); // timer advances without clock
      end
    join
    if (p0.bw.total_bytes !== 192 || p0.bw.total_events !== 3)
      $fatal(1,"raw cumulative accounting incorrect");
    $display("TB_PASS ns_bind"); $finish;
  end
endmodule
