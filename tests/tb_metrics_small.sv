module tb_metrics_small;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  int edge_number=0;
  bw_mon_setup setup();
  for(genvar g=0;g<4;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("metrics.small%0d",g)),.WINDOW_WIDTH(g==3 ? 4 : 1),.UPDATE_STRIDE(1),
      .FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) point
      (.clk(clk),.reset_n(1'b1),.valid(edge_number>=1 && edge_number<=(g==3 ? 3 : g+1)));
  end
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=7;t++)begin #(ns_to_ticks(t)-$time);edge_number=t;clk=1;#1;clk=0;end
    if(scopes[0].point.episode_result.variation.sample_count!=0 ||
       scopes[0].point.episode_result.variation.minmax_valid ||
       scopes[0].point.episode_result.variation.minmax_reason!=BW_METRIC_NO_SAMPLES ||
       scopes[1].point.episode_result.variation.sample_count!=1 ||
       !scopes[1].point.episode_result.variation.minmax_valid ||
       scopes[1].point.episode_result.variation.stddev_valid ||
       scopes[1].point.episode_result.variation.stddev_reason!=BW_METRIC_TOO_FEW_SAMPLES ||
       scopes[2].point.episode_result.variation.sample_count!=2 ||
       !scopes[2].point.episode_result.variation.stddev_valid ||
       !scopes[2].point.episode_result.variation.cv_valid ||
       scopes[2].point.episode_result.variation.stddev_gbps!=0.0 ||
       scopes[3].point.episode_result.variation.sample_count!=0 ||
       scopes[3].point.episode_result.variation.excluded_warmup!=2 ||
       !scopes[3].point.episode_result.variation.coverage_complete ||
       scopes[3].point.episode_result.variation.minmax_reason!=BW_METRIC_NO_SAMPLES ||
       !scopes[3].point.episode_result.e2e_valid)
      $fatal(1,"episode-only statistics distinguish0/1/2samples and ordinary warmup exclusions without requiring phase analysis");
    $display("TB_PASS metrics_small");$finish;
  end
endmodule
