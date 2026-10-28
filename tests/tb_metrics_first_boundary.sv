module tb_metrics_first_boundary;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("metrics.first_boundary"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .FIXED_BYTES(10),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5),
    .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
    .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
    .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
    .PHASE_RMS_ENTER_ABS(0.0),.PHASE_RMS_ENTER_REL(0.0),
    .PHASE_RMS_EXIT_ABS(0.0),.PHASE_RMS_EXIT_REL(0.0),
    .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_group_mon #(.GROUP_ID("metrics.first_boundary_group"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5),
    .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
    .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
    .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
    .PHASE_RMS_ENTER_ABS(0.0),.PHASE_RMS_ENTER_REL(0.0),
    .PHASE_RMS_EXIT_ABS(0.0),.PHASE_RMS_EXIT_REL(0.0),
    .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) aggregate
    (.clk(clk),.reset_n(1'b1));
  task automatic check_result(bw_episode_result_t result);
    if(result.status!=BW_EPISODE_COMPLETE ||
       result.first_known!=($test$plusargs("KNOWN_START") || $test$plusargs("UNKNOWN_END")) ||
       result.e2e_valid!=$test$plusargs("KNOWN_START") ||
       !result.last_steady_found ||
       result.last_steady_selection_valid==$test$plusargs("UNKNOWN_END") ||
       result.last_steady_reason!=($test$plusargs("UNKNOWN_END") ? BW_METRIC_BOUNDARY_UNKNOWN : BW_METRIC_OK))
      $fatal(1,"normal completion fixes the final steady selection independently of the episode start");
    if($test$plusargs("UNKNOWN_END"))begin
      if(result.last_known || !result.tail_known || result.duration_valid)
        $fatal(1,"later unknown activity leaves the last transfer uncertain despite an earlier actual tail");
      return;
    end
    if(result.last_steady.start_ticks!=4000001 || result.last_steady.end_ticks!=11250001 ||
       result.last_steady.byte_count!=70 || result.last_steady.duration_ticks!=7250000 ||
       !result.last_steady.bytes_complete || !result.last_steady.duration_valid ||
       !result.last_steady.bandwidth_valid ||
       $abs(result.last_steady.bandwidth_gbps-9.655172413793103)>1e-12 ||
       !result.last_steady.variation.stddev_valid ||
       result.last_steady.variation.sample_count!=8 ||
       result.last_steady.variation.mean_gbps!=10 || result.last_steady.variation.stddev_gbps!=0)
      $fatal(1,"complete final steady is70B/7.25ns and eight10GB/s windows, sigma0");
  endtask
  initial begin
    bw_report_summary_t summary;
    add_point_member("metrics.first_boundary_group","metrics.first_boundary");
    wait(monitor_ready);
    #250000;valid=($test$plusargs("KNOWN_START") || $test$plusargs("UNKNOWN_END")) ? 1'b0 : 1'bx;clk=1;#1;clk=0;
    for(int n=1;n<=10;n++)begin
      #(250000+ns_to_ticks(n)-$time);valid=1;clk=1;#1;clk=0;
    end
    #(11250002-$time);valid=0;clk=1;#1;clk=0;
    if($test$plusargs("UNKNOWN_END"))begin
      #(12250002-$time);valid=1'bx;clk=1;#1;clk=0;
      #(13250002-$time);valid=0;clk=1;#1;clk=0;
      #(19250003-$time);
    end else #(17250003-$time);
    check_result(point.episode_result);check_result(aggregate.episode_result);
    summary=check_report_summary();
    if(summary.pass_count!=($test$plusargs("UNKNOWN_END") ? 0 : 2) ||
       summary.fail_count!=($test$plusargs("UNKNOWN_END") ? 0 : 2) ||
       summary.warning_count!=($test$plusargs("UNKNOWN_END") ? 4 : 0))
      $fatal(1,"point and group independently FAIL steadyBW20 and PASS steady sigma0; got%0d/%0d/%0d",
        summary.pass_count,summary.fail_count,summary.warning_count);
    $display("TB_PASS metrics_first_boundary");$finish;
  end
endmodule
