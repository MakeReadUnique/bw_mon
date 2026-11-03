module tb_episode_boundary;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, valid=0;
  logic [63:0] size_bytes=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("episode.boundary"), .WINDOW_WIDTH(10), .UPDATE_STRIDE(7),
    .DYNAMIC_BYTES(1), .EPISODE_ENABLE(1), .SILENCE_THRESHOLD(30)) point
    (.clk(clk), .reset_n(1'b1), .valid(valid), .size_bytes(size_bytes), .size_known(1'b1));

  task automatic sample_at(bw_u64_t ticks, bit transfer, bw_u64_t bytes);
    #(ticks+1-$time); valid=transfer; size_bytes=bytes; clk=1;
    #1; clk=0;
  endtask

  initial begin
    wait(monitor_ready);
    for (int t=80; t<=102; t+=2)
      sample_at(ns_to_ticks(t), t==80 || t==84 || t==100, t==84 ? 128 : 64);
    #(132000001-$time);
    if (!point.episode_active || point.episode_result_seq!=0 ||
        point.episode_first_ticks!=80000001 || point.episode_last_ticks!=100000001 ||
        point.episode_tail_ticks!=102000001 || !point.episode_tail_known ||
        point.episode_bytes!=256 || point.episode_events!=3)
      $fatal(1,"episode must preserve the exact tail cycle and wait for Q independently of S");
    sample_at(132000000,1,128);
    if (point.episode_result_seq!=1 || !point.episode_active || point.episode_id!=2 ||
        point.episode_first_ticks!=132000001 || point.episode_bytes!=128 ||
        point.episode_tail_known || point.episode_result.episode_id!=1 ||
        point.episode_result.first_ticks!=80000001 || point.episode_result.tail_ticks!=102000001 ||
        point.episode_result.confirmation_ticks!=132000001 ||
        point.episode_result.duration_ticks!=22000000 || point.episode_result.byte_count!=256 ||
        point.episode_result.event_count!=3 || point.episode_result.start_total_bytes!=0 ||
        point.episode_result.end_total_bytes!=256 || !point.episode_result.e2e_valid ||
        $abs(point.episode_result.e2e_gbps-11.636363636363636)>1e-10)
      $fatal(1,"the Q-boundary transfer must start after the old [80,102) result completes");
    sample_at(134000000,0,0);
    #(164000001-$time);
    if (!point.episode_active || point.episode_result_seq!=1)
      $fatal(1,"stopped-clock silence must wait until the exact second deadline");
    #2;
    if (point.episode_active || point.episode_result_seq!=2 ||
        point.episode_result.first_ticks!=132000001 || point.episode_result.tail_ticks!=134000001 ||
        point.episode_result.confirmation_ticks!=164000001 ||
        point.episode_result.duration_ticks!=2000000 || !point.episode_result.e2e_valid ||
        point.episode_result.start_total_bytes!=256 || point.episode_result.end_total_bytes!=384 ||
        $abs(point.episode_result.e2e_gbps-64.0)>1e-10)
      $fatal(1,"single-event e2e includes its actual complete cycle and excludes confirmation silence");
    $display("TB_PASS episode_boundary"); $finish;
  end
endmodule
