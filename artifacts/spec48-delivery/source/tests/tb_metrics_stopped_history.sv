module tb_metrics_stopped_history;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic [63:0] bytes;
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("metrics.stopped%0d",g)),.WINDOW_WIDTH(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
      (.clk(clk),.reset_n(1'b1),.valid(1'b1),.size_bytes(bytes),.size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for(int t=0;t<9;t++)begin
      #(measurement_start_ticks+250000+ns_to_ticks(t)-$time);bytes=(t+1)*10;clk=1;#1;clk=0;
    end
    #(measurement_start_ticks+11500000-$time);
    if(scopes[0].point.episode_tail_known || scopes[0].point.episode_e2e_valid ||
       scopes[0].point.phase_result_seq!=1 || scopes[0].point.phase_result.phase_kind!=BW_PHASE_RAMP ||
       scopes[0].point.phase_result.start_ticks!=measurement_start_ticks+6000000 ||
       scopes[0].point.phase_result.end_ticks!=measurement_start_ticks+10000000 ||
       !scopes[0].point.phase_result.duration_valid || scopes[0].point.phase_result.duration_ticks!=4000000 ||
       !scopes[0].point.phase_result.bandwidth_valid || scopes[0].point.phase_result.bandwidth_gbps!=60.0 ||
       scopes[0].point.phase_result.variation.sample_count!=4 ||
       scopes[0].point.phase_result.variation.mean_gbps!=75 ||
       $abs(scopes[0].point.phase_result.variation.stddev_gbps-11.180339887498949)>1e-10)
      $fatal(1,"stopped clock proves[6,10) is covered by actual elapsed time without inventing a tail edge");
    $display("TB_PASS metrics_stopped_history");$finish;
  end
endmodule
