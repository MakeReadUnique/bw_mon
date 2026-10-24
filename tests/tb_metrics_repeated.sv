module tb_metrics_repeated;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes[2];
  int sequence_bytes[24]='{10,10,10,20,30,40,40,40,30,20,10,10,10,20,20,20,20,20,20,20,20,20,20,20};
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("phase.repeated%0d",g)),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4),
      .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
      .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
      .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
      .PHASE_RMS_ENTER_ABS(0.1),.PHASE_RMS_ENTER_REL(0.0),
      .PHASE_RMS_EXIT_ABS(0.1),.PHASE_RMS_EXIT_REL(0.0),
      .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) point
      (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes[g]),.size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=29;t++)begin
      #(ns_to_ticks(t)-$time);valid=t<=24;
      bytes[0]=(t<=24 ? sequence_bytes[t-1] : 0);bytes[1]=(t==24 ? 100 : bytes[0]);
      clk=1;#1;clk=0;
      if(t==8 && (scopes[0].point.phase_result_seq!=2 ||
          scopes[0].point.phase_result.phase_kind!=BW_PHASE_RAMP ||
          scopes[0].point.phase_result.start_ticks!=6000000 || scopes[0].point.phase_result.end_ticks!=8000000 ||
          scopes[0].point.phase_result.start_total_bytes!=80 || scopes[0].point.phase_result.end_total_bytes!=160))
        $fatal(1,"the first ramp has independent[6,8) boundaries and original byte snapshots");
      if(t==13 && (scopes[0].point.phase_result_seq!=4 ||
          scopes[0].point.phase_result.phase_kind!=BW_PHASE_FALL ||
          scopes[0].point.phase_result.start_ticks!=11000000 || scopes[0].point.phase_result.end_ticks!=13000000 ||
          scopes[0].point.phase_result.start_total_bytes!=250 || scopes[0].point.phase_result.end_total_bytes!=270))
        $fatal(1,"the first fall is independent of the preceding ramp and repeated plateaus");
      if(t==25 && (scopes[0].point.episode_result_seq!=0 ||
          scopes[0].point.episode_result.last_steady_selection_valid))
        $fatal(1,"last-steady selection must wait until the episode is final");
    end
    if(scopes[0].point.phase_result_seq!=6 || scopes[1].point.phase_result_seq!=6 ||
       scopes[0].point.phase_result.start_ticks!=17000000 || scopes[0].point.phase_result.end_ticks!=25000000 ||
       scopes[0].point.phase_result.byte_count!=160 || scopes[0].point.phase_result.bandwidth_gbps!=20.0 ||
       scopes[1].point.phase_result.byte_count!=240 || scopes[1].point.phase_result.bandwidth_gbps!=30.0 ||
       !scopes[0].point.episode_result.last_steady_selection_valid ||
       !scopes[1].point.episode_result.last_steady_selection_valid ||
       scopes[0].point.episode_result.last_steady.phase_id!=scopes[0].point.phase_result.phase_id ||
       scopes[0].point.episode_result.variation.sample_count!=23 ||
       scopes[1].point.episode_result.variation.sample_count!=23 ||
       scopes[0].point.episode_result.variation.first_sample_ticks!=2000000 ||
       scopes[0].point.episode_result.variation.last_sample_ticks!=24000000 ||
       $abs(scopes[0].point.episode_result.variation.mean_gbps-20.869565217391305)>1e-10 ||
       $abs(scopes[0].point.episode_result.variation.stddev_gbps-9.28441587133373)>1e-10 ||
       $abs(scopes[0].point.episode_result.variation.cv_pct-44.48782605013079)>1e-10 ||
       scopes[1].point.episode_result.variation.max_gbps!=40.0 ||
       scopes[0].point.phase_result.variation.sample_count!=8 ||
       scopes[1].point.phase_result.variation.sample_count!=8 ||
       scopes[1].point.phase_result.variation.min_gbps!=20.0 ||
       scopes[1].point.phase_result.variation.max_gbps!=20.0 ||
       scopes[1].point.phase_result.variation.stddev_gbps!=0.0 ||
       scopes[1].point.phase_result.variation.cv_pct!=0.0)
      $fatal(1,"final steady raw20/30 differs while half-open windows stay20; whole episode CV44.4878");
    $display("TB_PASS metrics_repeated");$finish;
  end
endmodule
