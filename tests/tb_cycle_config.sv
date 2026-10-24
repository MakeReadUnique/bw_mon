module tb_cycle_config;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("max.cycle.config"), .WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(80000), .UPDATE_STRIDE(80000), .FIXED_BYTES(0)) point
    (.clk(1'b0), .reset_n(1'b1), .valid(1'b0));
  initial begin
    wait(monitor_ready);
    #1000001;
    if (point.result_seq!=0 || point.total_events!=0 || point.denominator_valid)
      $fatal(1,"legal maximum cycle configuration must not invent clock activity");
    $display("TB_PASS cycle_config");
    $finish;
  end
endmodule
