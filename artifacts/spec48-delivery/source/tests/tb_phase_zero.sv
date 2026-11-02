module tb_phase_zero;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic [4:0] valid=0;
  bw_mon_setup setup();
  for(genvar g=0;g<5;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("phase.zero%0d",g)),.WINDOW_WIDTH(1),.FIXED_BYTES(0),.EPISODE_ENABLE(1)) point
      (.clk(clk),.reset_n(1'b1),.valid(valid[g]));
  end
  initial begin
    wait(monitor_ready);
    for(int t=0;t<=17;t++)begin
      #(measurement_start_ticks+250000+ns_to_ticks(t)-$time);
      valid[0]=t<6;valid[1]=t<4;valid[2]=0;valid[3]=t<4;valid[4]=t<6;
      clk=1;#1;clk=0;
      if(t==6 && (scopes[0].point.phase_current!=BW_PHASE_UNDETERMINED ||
         scopes[0].point.phase_candidate_count!=1 || scopes[0].point.phase_fit_mean!=0 ||
         scopes[0].point.phase_fit_rms!=0 || scopes[0].point.phase_fit_trend_rms!=0))
        $fatal(1,"six zero observations establish a zero-scale steady candidate");
      if(t==7 && (scopes[0].point.phase_current!=BW_PHASE_STEADY ||
         scopes[0].point.phase_start_ticks!=measurement_start_ticks+6000000 ||
         scopes[0].point.phase_confirmation_ticks!=measurement_start_ticks+7000000))
        $fatal(1,"zero activity confirms after two candidates independently of the actual tail");
    end
    if(scopes[0].point.phase_result_seq!=1 ||
       scopes[0].point.phase_result.start_ticks!=measurement_start_ticks+6000000 ||
       scopes[0].point.phase_result.end_ticks!=measurement_start_ticks+6250000 ||
       !scopes[0].point.episode_result.e2e_valid || scopes[0].point.episode_result.e2e_gbps!=0 ||
       scopes[1].point.phase_result_seq!=0 || !scopes[1].point.episode_result.e2e_valid ||
       scopes[2].point.episode_id!=0 || scopes[2].point.phase_id!=0 ||
       scopes[3].point.phase_result_seq!=0 || !scopes[3].point.episode_result.e2e_valid ||
       scopes[4].point.phase_result_seq!=1)
      $fatal(1,"final clipping distinguishes a short zero-byte episode from no activity");
    if(scopes[0].point.episode_result.variation.sample_count!=6 ||
       !scopes[0].point.episode_result.variation.stddev_valid ||
       scopes[0].point.episode_result.variation.stddev_gbps!=0 ||
       scopes[0].point.episode_result.variation.cv_valid ||
       scopes[0].point.episode_result.variation.cv_reason!=BW_METRIC_ZERO_MEAN ||
       scopes[0].point.phase_result.variation.sample_count!=1 ||
       !scopes[0].point.phase_result.variation.minmax_valid ||
       scopes[0].point.phase_result.variation.stddev_valid ||
       scopes[0].point.phase_result.variation.stddev_reason!=BW_METRIC_TOO_FEW_SAMPLES)
      $fatal(1,"zero mean and single selected sample have independent metric availability");
    $display("TB_PASS phase_zero");$finish;
  end
endmodule
