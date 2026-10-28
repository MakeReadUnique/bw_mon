module tb_metrics_controls;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  logic [1:0] reset_n=2'b11;
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("metrics.source%0d",g)),.WINDOW_WIDTH(1),.FIXED_BYTES(10)) point
      (.clk(clk),.reset_n(reset_n[g]),.valid(valid));
    bw_group_mon #(.GROUP_ID($sformatf("metrics.ancestor%0d",g)),.WINDOW_WIDTH(1),
      .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4)) ancestor(.clk(clk),.reset_n(1'b1));
    initial add_point_member($sformatf("metrics.ancestor%0d",g),$sformatf("metrics.source%0d",g));
  end
  initial begin
    wait(monitor_ready);
    for(int t=0;t<=30;t++)begin
      #(measurement_start_ticks+250000+ns_to_ticks(t)-$time);valid=t<30;clk=1;#1;clk=0;
      if(t==17 && (scopes[0].ancestor.phase_result.start_ticks!=measurement_start_ticks+6000000 ||
         scopes[0].ancestor.phase_result.end_ticks!=measurement_start_ticks+17000000 ||
         !scopes[0].ancestor.phase_result.duration_valid || scopes[0].ancestor.phase_result.duration_ticks!=11000000 ||
         scopes[0].ancestor.phase_result.bytes_complete || scopes[0].ancestor.phase_result.events_complete ||
         scopes[0].ancestor.phase_result.bandwidth_valid || !scopes[0].ancestor.phase_result.variation.stddev_valid ||
         scopes[0].ancestor.phase_result.variation.sample_count!=11 || scopes[0].ancestor.phase_result.variation.mean_gbps!=10 ||
         scopes[0].ancestor.phase_result.end_unknown_ticks-scopes[0].ancestor.phase_result.start_unknown_ticks!=100000))
        $fatal(1,"a no-edge unknown member interval invalidates raw bytes while earlier windows and duration stay complete");
    end
    #(measurement_start_ticks+35250000-$time);
    if(scopes[0].ancestor.phase_result.bytes_complete==$test$plusargs("LATE_GAP") ||
       scopes[0].ancestor.phase_result.bandwidth_valid==$test$plusargs("LATE_GAP") ||
       scopes[0].ancestor.phase_result.start_ticks!=measurement_start_ticks+23000000 ||
       scopes[0].ancestor.phase_result.end_ticks!=measurement_start_ticks+($test$plusargs("LATE_GAP") ? 30000000 : 30250000) ||
       !scopes[0].ancestor.phase_result.variation.stddev_valid ||
       scopes[0].ancestor.episode_result.e2e_valid || scopes[0].ancestor.episode_result.variation.stddev_valid ||
       scopes[0].ancestor.episode_result.variation.unknown_samples!=($test$plusargs("LATE_GAP") ? 2 : 1) ||
       !scopes[1].ancestor.episode_result.e2e_valid || !scopes[1].ancestor.episode_result.variation.stddev_valid ||
       !scopes[1].ancestor.phase_result.bytes_complete || !scopes[1].ancestor.phase_result.member_reset_coverage ||
       !scopes[1].ancestor.episode_result.member_reset_coverage || !scopes[1].ancestor.phase_result.bandwidth_valid)
      $fatal(1,"raw interval quality, selected windows, later recovery, and known member reset coverage remain independent");
    $display("TB_PASS metrics_controls");$finish;
  end
  initial begin
    wait(monitor_ready);#16100000;reset_n[0]=1'bx;reset_n[1]=0;#100000;reset_n=2'b11;
    if($test$plusargs("LATE_GAP"))begin #12900000;reset_n[0]=1'bx;reset_n[1]=0;#100000;reset_n=2'b11;end
  end
endmodule
