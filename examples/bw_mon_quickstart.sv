module bw_mon_quickstart;
  timeunit 1ns;
  timeprecision 1fs;
  import bw_mon_pkg::*;

  logic clk = 0;
  logic reset_n = 0;
  logic valid = 0;
  logic ready = 1;

  // 1 GHz 时钟，每个周期为 1 ns。
  always #0.5ns clk = ~clk;

  // 整个 testbench 只放一个 setup，填写实际观测点总数。
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) u_bw_setup();

  bw_point_mon #(
    .POINT_ID("master0"),
    .PROTOCOL(BW_VALID_READY),
    .FIXED_BYTES(64),
    .WINDOW_BASIS(BW_NS),
    .WINDOW_WIDTH(10),
    .UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),
    .SILENCE_THRESHOLD(10)
  ) u_bw (
    .clk(clk),
    .reset_n(reset_n),
    .valid(valid),
    .ready(ready)
  );

  initial begin
    wait (monitor_ready);
    // 在下降沿改激励，供后面的上升沿采样。
    repeat (2) @(negedge clk);
    reset_n = 1;
    valid = 1;

    // 连续传输 20 拍，每拍 64 字节，共 1280 字节。
    repeat (20) @(negedge clk);
    valid = 0;
    #1fs; // 等当前时刻的统计更新完成后读取。
    $display("QUICKSTART window_bytes=%0d bandwidth_gbps=%0.3f window_valid=%0b",
             u_bw.window_bytes, u_bw.bandwidth_gbps, u_bw.window_valid);

    // 保持时钟运行，等待末拍结束和 10 ns 静默确认。
    repeat (12) @(negedge clk);
    #1fs;
    $display("QUICKSTART total_bytes=%0d total_events=%0d e2e_gbps=%0.3f e2e_valid=%0b",
             u_bw.total_bytes, u_bw.total_events,
             u_bw.episode_result_e2e_gbps, u_bw.episode_result_e2e_valid);
    $finish;
  end
endmodule
