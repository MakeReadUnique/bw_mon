module tb_phase_repeated;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes[2];
  int sequence_bytes[40]='{10,10,10,20,30,40,40,40,30,20,10,10,10,20,20,20,20,20,20,20,
    20,20,20,20,30,40,50,50,50,40,30,20,20,20,20,20,20,20,20,20};
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
    for(int t=1;t<=45;t++)begin
      #(ns_to_ticks(t)-$time);valid=t<=40;
      bytes[0]=(t<=40 ? sequence_bytes[t-1] : 0);bytes[1]=(t==40 ? 100 : bytes[0]);
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
      if(t==29 && (scopes[0].point.phase_result_seq!=7 ||
          scopes[0].point.phase_result.phase_kind!=BW_PHASE_RAMP ||
          scopes[0].point.phase_result.start_ticks!=27000000 || scopes[0].point.phase_result.end_ticks!=29000000))
        $fatal(1,"a second ramp is allowed after earlier fall and steady phases");
      if(t==34 && (scopes[0].point.phase_result_seq!=9 ||
          scopes[0].point.phase_result.phase_kind!=BW_PHASE_FALL ||
          scopes[0].point.phase_result.start_ticks!=32000000 || scopes[0].point.phase_result.end_ticks!=34000000))
        $fatal(1,"a second fall is retained as its own final interval");
    end
    if(scopes[0].point.phase_result_seq!=10 || scopes[1].point.phase_result_seq!=10 ||
       scopes[0].point.phase_result.phase_kind!=BW_PHASE_STEADY || scopes[0].point.phase_result.phase_id!=10 ||
       scopes[0].point.phase_result.start_ticks!=35000000 || scopes[0].point.phase_result.end_ticks!=41000000 ||
       scopes[1].point.phase_result.start_ticks!=35000000 || scopes[1].point.phase_result.end_ticks!=41000000 ||
       scopes[0].point.phase_result.start_total_bytes!=850 || scopes[1].point.phase_result.start_total_bytes!=850 ||
       scopes[0].point.phase_result.end_total_bytes!=970 || scopes[1].point.phase_result.end_total_bytes!=1050 ||
       !scopes[0].point.phase_result.end_known || !scopes[1].point.phase_result.end_known ||
       scopes[0].point.episode_result.e2e_gbps!=24.25 || scopes[1].point.episode_result.e2e_gbps!=26.25)
      $fatal(1,"final clipping discards trailing confirmed stages and preserves the last raw cycle at the right endpoint");
    $display("TB_PASS phase_repeated");$finish;
  end
endmodule
