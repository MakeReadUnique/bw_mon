module tb_report_metrics_repeated;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes[2];
  int sequence_bytes[24]='{10,10,10,20,30,40,40,40,30,20,10,10,10,20,20,20,20,20,20,20,20,20,20,20};
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("phase.repeated%0d",g)),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4),
      .PHASE_ENABLE(1)) point
      (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes[g]),.size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=29;t++)begin
      #(measurement_start_ticks+ns_to_ticks(t)-$time);valid=t<=24;
      bytes[0]=(t<=24 ? sequence_bytes[t-1] : 0);bytes[1]=(t==24 ? 100 : bytes[0]);
      clk=1;#1;clk=0;
      if(t==25 && (scopes[0].point.episode_result_seq!=0 ||
          scopes[0].point.episode_result.last_steady_selection_valid))
        $fatal(1,"last-steady selection must wait until the episode is final");
    end
    if(scopes[0].point.phase_result_seq!=1 || scopes[1].point.phase_result_seq!=1 ||
       scopes[0].point.phase_result.start_ticks!=measurement_start_ticks+20000000 || scopes[0].point.phase_result.end_ticks!=measurement_start_ticks+25000000 ||
       scopes[0].point.phase_result.byte_count!=100 || scopes[0].point.phase_result.bandwidth_gbps!=20.0 ||
       scopes[1].point.phase_result.byte_count!=180 || scopes[1].point.phase_result.bandwidth_gbps!=36.0 ||
       !scopes[0].point.episode_result.last_steady_selection_valid ||
       !scopes[1].point.episode_result.last_steady_selection_valid ||
       scopes[0].point.episode_result.last_steady.phase_id!=scopes[0].point.phase_result.phase_id ||
       scopes[0].point.episode_result.variation.sample_count!=23 ||
       scopes[1].point.episode_result.variation.sample_count!=23 ||
       scopes[0].point.episode_result.variation.first_sample_ticks!=measurement_start_ticks+2000000 ||
       scopes[0].point.episode_result.variation.last_sample_ticks!=measurement_start_ticks+24000000 ||
       $abs(scopes[0].point.episode_result.variation.mean_gbps-20.869565217391305)>1e-10 ||
       $abs(scopes[0].point.episode_result.variation.stddev_gbps-9.28441587133373)>1e-10 ||
       $abs(scopes[0].point.episode_result.variation.cv_pct-44.48782605013079)>1e-10 ||
       scopes[1].point.episode_result.variation.max_gbps!=40.0 ||
       scopes[0].point.phase_result.variation.sample_count!=5 ||
       scopes[1].point.phase_result.variation.sample_count!=5 ||
       scopes[1].point.phase_result.variation.min_gbps!=20.0 ||
       scopes[1].point.phase_result.variation.max_gbps!=20.0 ||
       scopes[1].point.phase_result.variation.stddev_gbps!=0.0 ||
       scopes[1].point.phase_result.variation.cv_pct!=0.0)
      $fatal(1,"final steady raw20/36 differs while half-open windows stay20; whole episode CV44.4878");
    if($test$plusargs("BW_EXPECT"))begin
      bw_report_summary_t checked;
      checked=check_report_summary();
      if(checked.pass_count!=($test$plusargs("FULL_METRICS") ? 17 : 2) || checked.fail_count!=($test$plusargs("FULL_METRICS") ? 3 : 2) || checked.warning_count!=6 || checked.finalized)
        $fatal(1,"short earlier trends remain unconfirmed; raw steady36 and whole-episode CV retain independent explicit verdicts");
    end
    $display("TB_PASS report_metrics_repeated continued_after_metric_fail=1");$finish;
  end
endmodule
