module tb_phase_hysteresis;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] size[2];
  int bytes_by_sample[12]='{10,10,10,10,11,12,14,16,18,20,22,24};
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("phase.hysteresis%0d",g)),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5),
      .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(2),
      .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
      .PHASE_STEADY_EXIT_ABS(2.0),.PHASE_STEADY_EXIT_REL(0.0),
      .PHASE_RMS_ENTER_ABS(0.5),.PHASE_RMS_ENTER_REL(0.0),
      .PHASE_RMS_EXIT_ABS(1.0),.PHASE_RMS_EXIT_REL(0.0),
      .PHASE_TREND_ABS(3.0),.PHASE_TREND_REL(0.0)) point
      (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(size[g]),.size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for(int n=0;n<12;n++)begin
      #(250000+ns_to_ticks(n)-$time);valid=1;
      size[0]=bytes_by_sample[n];size[1]=(n==7) ? 64'bx : bytes_by_sample[n];
      clk=1;#1;clk=0;
    end
    #(12250002-$time);valid=0;clk=1;#1;clk=0;
  end
  initial begin
    wait(monitor_ready);
    #3000001;
    if(scopes[0].point.phase_candidate!=BW_PHASE_STEADY || scopes[0].point.phase_candidate_count!=1)
      $fatal(1,"stable candidate requires the first three eligible published results");
    #1000000;
    if(scopes[0].point.phase_current!=BW_PHASE_STEADY || scopes[0].point.phase_start_ticks!=3000001 ||
       scopes[0].point.phase_confirmation_ticks!=4000001)
      $fatal(1,"K2 confirms stable with its earlier candidate boundary");
    #1000000;
    if(scopes[0].point.phase_current!=BW_PHASE_STEADY || scopes[0].point.phase_fit_delta!=1.0 ||
       $abs(scopes[0].point.phase_fit_rms-0.23570226039551584)>1e-10)
      $fatal(1,"wider exit thresholds hold stable while strict entry is false");
    #1000000;
    if(scopes[0].point.phase_current!=BW_PHASE_STEADY || scopes[0].point.phase_fit_delta!=2.0)
      $fatal(1,"equality at the stable exit threshold must still hold");
    #1000000;
    if(scopes[0].point.phase_candidate!=BW_PHASE_RAMP || scopes[0].point.phase_candidate_count!=1 ||
       scopes[1].point.phase_candidate_count!=1)
      $fatal(1,"trend creates a fresh candidate without prematurely replacing the current phase");
    #1000000;
    if(scopes[0].point.phase_current!=BW_PHASE_RAMP || scopes[0].point.phase_start_ticks!=7000001 ||
       scopes[0].point.phase_confirmation_ticks!=8000001 || scopes[0].point.phase_result_seq!=1 ||
       scopes[0].point.phase_result.start_ticks!=3000001 || scopes[0].point.phase_result.end_ticks!=7000001 ||
       scopes[0].point.phase_result.start_total_bytes!=30 || scopes[0].point.phase_result.end_total_bytes!=77)
      $fatal(1,"new ramp confirmation backtracks the old steady's final raw-count boundary");
    if(scopes[1].point.phase_current!=BW_PHASE_UNDETERMINED || scopes[1].point.phase_active ||
       scopes[1].point.phase_candidate_count!=0 || scopes[1].point.phase_evidence_count!=0 ||
       scopes[1].point.phase_evidence_continuous)
      $fatal(1,"invalid byte evidence breaks current phase and candidate immediately, independent of K");
    #1000000;
    if(scopes[1].point.phase_evidence_count!=1 || scopes[1].point.phase_result_seq!=1 ||
       scopes[1].point.phase_result.phase_kind!=BW_PHASE_STEADY)
      $fatal(1,"recovery starts a new evidence chain and retains the old confirmed fragment");
    #2000000;
    if(scopes[1].point.phase_candidate!=BW_PHASE_RAMP || scopes[1].point.phase_candidate_count!=1 ||
       scopes[1].point.phase_candidate_ticks!=11000000)
      $fatal(1,"recovered N-point evidence must restart candidate confirmation");
    #1000000;
    if(scopes[1].point.phase_current!=BW_PHASE_RAMP || scopes[1].point.phase_start_ticks!=11000001 ||
       scopes[1].point.phase_confirmation_ticks!=12000001)
      $fatal(1,"a fresh K-chain confirms only after recovery");
    #(18000003-$time);
    if(scopes[0].point.phase_result_seq!=2 || scopes[1].point.phase_result_seq!=2 ||
       scopes[0].point.phase_result.end_ticks!=12250001 || scopes[1].point.phase_result.end_ticks!=12250001 ||
       !scopes[0].point.episode_result.e2e_valid || scopes[1].point.episode_result.e2e_valid)
      $fatal(1,"final phase clipping and whole-episode byte quality remain independent");
    $display("TB_PASS phase_hysteresis");$finish;
  end
endmodule
