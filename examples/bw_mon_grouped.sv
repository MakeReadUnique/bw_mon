// Two existing interface instances observed by one module-type bind.
module bw_mon_example_port (
  input logic clk, reset_n, valid, ready
);
  timeunit 1ns;
  timeprecision 1fs;
endmodule

bind bw_mon_example_port bw_point_mon #(
  .PROTOCOL(bw_mon_pkg::BW_VALID_READY),
  .FIXED_BYTES(64),
  .WINDOW_WIDTH(10),
  .UPDATE_STRIDE(1),
  .EPISODE_ENABLE(1)
) u_bw (
  .clk(clk), .reset_n(reset_n), .valid(valid), .ready(ready)
);

module bw_mon_grouped;
  timeunit 1ns;
  timeprecision 1fs;
  import bw_mon_pkg::*;

  logic clk = 0;
  logic reset_n = 0;
  logic valid = 0;
  always #0.5ns clk = ~clk;

  bw_mon_example_port mem0 (
    .clk(clk), .reset_n(reset_n), .valid(valid), .ready(1'b1)
  );
  bw_mon_example_port mem1 (
    .clk(clk), .reset_n(reset_n), .valid(valid), .ready(1'b1)
  );

  bw_mon_setup u_bw_setup();
  bw_group_mon #(
    .GROUP_ID("all_mem"),
    .WINDOW_WIDTH(10),
    .UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1)
  ) all_mem (
    .clk(clk), .reset_n(reset_n)
  );

  // Member rules use Point IDs. With no POINT_ID override, each bound
  // monitor's full path is its Point ID. Configure members at actual t=0.
  initial begin
    add_point_member("all_mem", "bw_mon_grouped.mem0.u_bw");
    add_point_member("all_mem", "bw_mon_grouped.mem1.u_bw");
  end

  initial begin
    wait (monitor_ready);
    repeat (2) @(negedge clk);
    reset_n = 1;
    valid = 1;

    // Forty real transfer edges: 2560 B per point, 5120 B for the group.
    // This also leaves enough complete windows for the default phase/checker.
    repeat (40) @(negedge clk);
    valid = 0;
    #1fs;
    $display("GROUPED window0=%0d window1=%0d window_group=%0d bandwidth_group=%0.3f window_valid=%0b",
      mem0.u_bw.window_bytes, mem1.u_bw.window_bytes,
      all_mem.window_bytes, all_mem.bandwidth_gbps, all_mem.window_valid);

    // Allow the actual tail edge and the omitted Q=10 ns silence threshold.
    repeat (12) @(negedge clk);
    #1fs;
    $display("GROUPED total0=%0d total1=%0d total_group=%0d e2e_group=%0.3f e2e_valid=%0b",
      mem0.u_bw.total_bytes, mem1.u_bw.total_bytes, all_mem.total_bytes,
      all_mem.episode_result_e2e_gbps, all_mem.episode_result_e2e_valid);
    $finish;
  end
endmodule
