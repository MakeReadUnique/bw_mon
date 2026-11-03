module tb_phase_delayed;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.delayed"),.WINDOW_WIDTH(100),.UPDATE_STRIDE(10),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(60)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes),.size_known(1'b1));
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=216;t++)begin
      #(measurement_start_ticks+ns_to_ticks(t)-$time);valid=t==95 || t==155;bytes=t==95 ? 640 : 0;
      clk=1;#1;clk=0;
      if(t==150 && (point.phase_candidate!=BW_PHASE_STEADY || point.phase_candidate_count!=1 ||
         point.phase_candidate_ticks!=measurement_start_ticks+150000000 ||
         point.phase_current!=BW_PHASE_UNDETERMINED || point.phase_candidate_total_bytes!=640 ||
         point.phase_candidate_total_events!=1))$fatal(1,"six complete windows first qualify at150");
      if(t==160 && (point.phase_current!=BW_PHASE_STEADY || point.phase_evidence_count!=6 ||
         point.phase_start_ticks!=measurement_start_ticks+150000000 ||
         point.phase_confirmation_ticks!=measurement_start_ticks+160000000 ||
         $abs(point.phase_fit_mean-6.4)>1e-10 || point.phase_fit_delta!=0 || point.phase_fit_rms!=0))
        $fatal(1,"confirmation160 retains boundary150 even though measured tail is156");
    end
    if(point.phase_result_seq!=1 || point.phase_result.start_ticks!=measurement_start_ticks+150000000 ||
       point.phase_result.end_ticks!=measurement_start_ticks+156000000 ||
       point.phase_result.confirmation_ticks!=measurement_start_ticks+160000000 ||
       point.phase_result.start_total_bytes!=640 || point.phase_result.end_total_bytes!=640 ||
       point.phase_result.duration_ticks!=6000000 || !point.phase_result.bandwidth_valid ||
       point.phase_result.bandwidth_gbps!=0 || point.phase_result.variation.sample_count!=1 ||
       $abs(point.phase_result.variation.mean_gbps-6.4)>1e-10 ||
       point.phase_result.variation.stddev_valid || !point.phase_result.variation.minmax_valid ||
       point.episode_result_seq!=1 || !point.episode_result.e2e_valid ||
       $abs(point.episode_result.e2e_gbps-640.0/61.0)>1e-10 ||
       point.episode_result.variation.sample_count!=6 || !point.episode_result.variation.stddev_valid ||
       point.episode_result.variation.stddev_gbps!=0 || !point.episode_result.last_steady_selection_valid)
      $fatal(1,"final[150,156) raw0 and one6.4 window preserve complete640B/61ns episode");
    $display("TB_PASS phase_delayed");$finish;
  end
endmodule
