module tb_metrics_interrupted;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  logic [63:0] bytes=10;
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("metrics.interrupted%0d",g)),.WINDOW_WIDTH(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
      (.clk(clk),.reset_n(g==0 ? reset_n : 1'b1),.valid(1'b1),.size_bytes(bytes),.size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for(int t=0;t<=20;t++)begin
      #(measurement_start_ticks+250000+ns_to_ticks(t)-$time);bytes=t<10 ? (t+1)*10 : 100;
      clk=1;#1;clk=0;
      if(t==13 && (scopes[0].point.phase_result_seq!=1 ||
         scopes[0].point.phase_result.phase_kind!=BW_PHASE_RAMP ||
         scopes[0].point.phase_result.start_ticks!=measurement_start_ticks+6000000 ||
         scopes[0].point.phase_result.end_ticks!=measurement_start_ticks+12000000 ||
         scopes[0].point.phase_result.duration_ticks!=6000000 ||
         scopes[0].point.phase_result.byte_count!=540 || scopes[0].point.phase_result.bandwidth_gbps!=90 ||
         scopes[0].point.phase_result.variation.sample_count!=6 ||
         $abs(scopes[0].point.phase_result.variation.mean_gbps-83.33333333333333)>1e-10 ||
         $abs(scopes[0].point.phase_result.variation.stddev_gbps-14.9071198499986)>1e-10))
        $fatal(1,"settled ramp[6,12) retains raw540B/6ns and independent six-window distribution");
    end
    #(measurement_start_ticks+20500000-$time);reset_n=0;#1;
    if(scopes[0].point.episode_result.status!=BW_EPISODE_RESET_INTERRUPTED ||
       scopes[0].point.episode_result.last_steady_selection_valid ||
       scopes[0].point.episode_result.last_steady_reason!=BW_METRIC_RESET ||
       scopes[0].point.phase_result_seq!=2 || scopes[1].point.phase_result_seq!=1)
      $fatal(1,"reset retains earlier ramp evidence but cannot complete the unresolved last steady");
    #(measurement_start_ticks+21500000-$time);
    $display("TB_PASS metrics_interrupted");$finish;
  end
endmodule
