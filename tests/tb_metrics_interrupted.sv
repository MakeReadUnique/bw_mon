module tb_metrics_interrupted;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  logic [63:0] bytes;
  int values[9]='{10,10,10,20,30,40,40,40,30};
  bw_phase_result_t saved_ramp[2];
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("metrics.interrupted%0d",g)),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4),
      .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
      .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
      .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
      .PHASE_RMS_ENTER_ABS(0.1),.PHASE_RMS_ENTER_REL(0.0),
      .PHASE_RMS_EXIT_ABS(0.1),.PHASE_RMS_EXIT_REL(0.0),
      .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) point
      (.clk(clk),.reset_n(g==0 ? reset_n : 1'b1),.valid(1'b1),.size_bytes(bytes),.size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=9;t++)begin
      #(ns_to_ticks(t)-$time);bytes=values[t-1];clk=1;#1;clk=0;
      if(t==8)begin
        saved_ramp[0]=scopes[0].point.phase_result;saved_ramp[1]=scopes[1].point.phase_result;
        if(saved_ramp[0].phase_kind!=BW_PHASE_RAMP || !saved_ramp[0].duration_valid ||
           saved_ramp[0].duration_ticks!=2000000 || saved_ramp[0].bandwidth_gbps!=40.0 ||
           saved_ramp[0].variation.sample_count!=2 || saved_ramp[0].variation.mean_gbps!=35.0 ||
           saved_ramp[0].variation.stddev_gbps!=5.0 || !saved_ramp[0].variation.stddev_valid)
          $fatal(1,"settled ramp[6,8) has duration2/raw40 and population sigma5 despite fitRMS0");
      end
    end
    #(9500002-$time);reset_n=0;#1;
    if(scopes[0].point.episode_result.status!=BW_EPISODE_RESET_INTERRUPTED ||
       scopes[0].point.episode_result.variation.stddev_valid ||
       scopes[0].point.episode_result.variation.stddev_reason!=BW_METRIC_RESET ||
       scopes[0].point.episode_result.last_steady_selection_valid ||
       scopes[0].point.episode_result.last_steady_reason!=BW_METRIC_RESET ||
       scopes[0].point.phase_result.duration_reason!=BW_METRIC_RESET ||
       scopes[0].point.phase_result.variation.stddev_reason!=BW_METRIC_RESET ||
       !saved_ramp[0].duration_valid || !saved_ramp[0].variation.stddev_valid ||
       !saved_ramp[1].bandwidth_valid)
      $fatal(1,"reset cannot erase an earlier complete ramp or turn an unresolved last steady into a representative");
    #(10000002-$time);
    $display("TB_PASS metrics_interrupted");$finish;
  end
endmodule
