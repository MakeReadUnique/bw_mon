module tb_phase_actual_time;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  logic [63:0] bytes=0;
  bw_u64_t ticks[9]='{250000,1250000,2250000,4250000,4750000,5250000,6250000,8250000,10250000};
  int values[9]='{110,118,268,69,71,150,332,364,0};
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.actual"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes),.size_known(1'b1));
  initial begin
    bw_u64_t seq,identity;
    wait(monitor_ready);
    for(int i=0;i<9;i++)begin
      #(measurement_start_ticks+ticks[i]-$time);bytes=values[i];valid=i<8;
      clk=1;#1;clk=0;
      if(i==6 && (point.phase_candidate!=BW_PHASE_RAMP || point.phase_candidate_count!=1 ||
         $abs(point.phase_fit_delta-40.0)>1e-10 || point.phase_fit_rms>1e-10 || point.phase_fit_trend_rms>1e-10))
        $fatal(1,"six unequal-spaced physical-time points on y=100+8t must form a paired linear fit");
      if(i==7 && (point.phase_current!=BW_PHASE_RAMP ||
         point.phase_start_ticks!=measurement_start_ticks+6250000 ||
         point.phase_confirmation_ticks!=measurement_start_ticks+8250000 ||
         point.phase_fit_rms>1e-10 || point.phase_fit_trend_rms>1e-10))
        $fatal(1,"sub-ns frequency changes preserve physical fit and independent confirmation time");
    end
    seq=point.result_seq;identity=point.phase_id;#2000000;
    if(point.result_seq!=seq || point.phase_id!=identity || point.episode_result_seq!=0)
      $fatal(1,"held cycle snapshots cannot add samples, confirm stages or advance cycle silence");
    clk=1;#1;clk=0;#1000000;clk=1;#1;clk=0;
    if(point.phase_result_seq!=1 || point.phase_result.phase_kind!=BW_PHASE_RAMP ||
       point.phase_result.duration_ticks!=4000000 || point.phase_result.byte_count!=696 ||
       !point.phase_result.bandwidth_valid || point.phase_result.bandwidth_gbps!=174.0 ||
       point.phase_result.variation.sample_count!=2 || point.phase_result.variation.mean_gbps!=158.0 ||
       point.phase_result.variation.stddev_gbps!=8.0 || !point.phase_result.variation.cv_valid)
      $fatal(1,"raw696B/4ns differs from equal-weight150/166 window mean158 sigma8");
    $display("TB_PASS phase_actual_time");$finish;
  end
endmodule
