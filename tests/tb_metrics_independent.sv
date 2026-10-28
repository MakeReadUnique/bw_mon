module tb_metrics_independent;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("metrics.independent"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes),.size_known(1'b1));
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=6;t++)begin
      #(ns_to_ticks(t)-$time);valid=t<=3;bytes=t==3 ? 64'bx : t*10;clk=1;#1;clk=0;
    end
    if(point.episode_result.e2e_valid || point.episode_result.bytes_complete ||
       !point.episode_result.events_complete || !point.episode_result.duration_valid ||
       point.episode_result.variation.sample_count!=2 ||
       !point.episode_result.variation.minmax_valid || !point.episode_result.variation.stddev_valid ||
       !point.episode_result.variation.cv_valid || !point.episode_result.variation.coverage_complete ||
       point.episode_result.variation.unknown_samples!=0 ||
       point.episode_result.variation.mean_gbps!=15.0 || point.episode_result.variation.stddev_gbps!=5.0 ||
       $abs(point.episode_result.variation.cv_pct-33.333333333333333)>1e-10)
      $fatal(1,"unknown last raw size invalidates e2e but its publication is at excluded tail4; selected10/20 samples remain complete");
    $display("TB_PASS metrics_independent");$finish;
  end
endmodule
