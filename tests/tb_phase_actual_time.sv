module tb_phase_actual_time;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(3)) setup();
  for(genvar g=0;g<3;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("phase.actual_time%0d",g)),.WINDOW_BASIS(BW_CYCLE),
      .WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(20),
      .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(g==1 ? 3 : 2),.PHASE_K(1),
      .PHASE_STEADY_ENTER_ABS(g==2 ? 0.0 : 0.1),.PHASE_STEADY_ENTER_REL(g==2 ? 0.5 : 0.0),
      .PHASE_STEADY_EXIT_ABS(g==2 ? 0.0 : 0.2),.PHASE_STEADY_EXIT_REL(g==2 ? 0.6 : 0.0),
      .PHASE_RMS_ENTER_ABS(0.01),.PHASE_RMS_ENTER_REL(0.0),
      .PHASE_RMS_EXIT_ABS(0.01),.PHASE_RMS_EXIT_REL(0.0),
      .PHASE_TREND_ABS(g==2 ? 1.0 : 5.0),.PHASE_TREND_REL(g==2 ? 0.7 : 0.0)) point
      (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes),.size_known(1'b1));
  end
  task automatic sample_at(bw_u64_t tick,bit transfer,bw_u64_t count);
    #(tick-$time);valid=transfer;bytes=count;clk=1;#1;clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    sample_at(10000000,1,10);sample_at(11000000,1,12);
    sample_at(12000000,1,32);sample_at(14000000,1,8);
    if(scopes[0].point.phase_current!=BW_PHASE_RAMP || scopes[0].point.phase_start_ticks!=14000000 ||
       $abs(scopes[0].point.phase_fit_mean-12.666666666666666)>1e-10 ||
       $abs(scopes[0].point.phase_fit_delta-6.0)>1e-10 ||
       $abs(scopes[0].point.phase_fit_rms)>1e-10 || scopes[0].point.phase_evidence_span!=2)
      $fatal(1,"10/12/16GBps at11/12/14ns is a physical-time line with delta6 and zero residual");
    if(scopes[1].point.phase_evidence_count!=3 || scopes[1].point.phase_evidence_sufficient ||
       scopes[1].point.phase_fit_valid || scopes[1].point.phase_current!=BW_PHASE_UNDETERMINED)
      $fatal(1,"N samples alone cannot bypass the configured span in local cycles");
    if(scopes[2].point.phase_current!=BW_PHASE_STEADY ||
       $abs(scopes[2].point.phase_fit_delta-6.0)>1e-10)
      $fatal(1,"absolute plus relative-times-mean thresholds can classify a nonzero trend as steady");
    #(99000000-$time);
    if(scopes[0].point.result_seq!=3 || scopes[0].point.phase_window_seq!=3 ||
       scopes[0].point.phase_evidence_count!=3 || scopes[0].point.phase_id!=1 ||
       scopes[0].point.phase_result_seq!=0 || scopes[0].point.phase_confirmation_ticks!=14000000)
      $fatal(1,"held cycle snapshots cannot create new evidence, confirmation or final records");
    sample_at(100000000,0,0);
    if(scopes[0].point.phase_result_seq!=1 || scopes[0].point.phase_result.phase_kind!=BW_PHASE_RAMP ||
       scopes[0].point.phase_result.start_ticks!=14000000 || scopes[0].point.phase_result.end_ticks!=100000000 ||
       !scopes[0].point.phase_result.end_known || scopes[0].point.phase_result.start_total_bytes!=54 ||
       scopes[0].point.phase_result.end_total_bytes!=62 || scopes[1].point.phase_fit_valid)
      $fatal(1,"the resumed actual edge finalizes earlier phase bounds without weighting old held windows");
    $display("TB_PASS phase_actual_time");$finish;
  end
endmodule
