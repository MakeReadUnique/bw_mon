module tb_phase_candidate_change;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=0;
  int values[10]='{0,0,0,2,4,0,0,0,0,0};
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.candidate_change"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5),
    .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(3),
    .PHASE_STEADY_ENTER_ABS(0.0),.PHASE_STEADY_ENTER_REL(0.0),
    .PHASE_STEADY_EXIT_ABS(0.0),.PHASE_STEADY_EXIT_REL(0.0),
    .PHASE_RMS_ENTER_ABS(100.0),.PHASE_RMS_ENTER_REL(0.0),
    .PHASE_RMS_EXIT_ABS(100.0),.PHASE_RMS_EXIT_REL(0.0),
    .PHASE_TREND_ABS(1.0),.PHASE_TREND_REL(0.0)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes),.size_known(1'b1));
  initial begin
    wait(monitor_ready);
    for(int n=0;n<10;n++)begin
      #(250000+ns_to_ticks(n)-$time);valid=1;bytes=values[n];clk=1;#1;clk=0;
    end
    #(10250002-$time);valid=0;clk=1;#1;clk=0;
  end
  initial begin
    wait(monitor_ready);#5000001;
    if(point.phase_candidate!=BW_PHASE_RAMP || point.phase_candidate_count!=2 ||
       point.phase_candidate_ticks!=4000000 || point.phase_current!=BW_PHASE_UNDETERMINED)
      $fatal(1,"a changed candidate starts at one rather than inheriting the earlier stable count");
    #1000000;
    if(point.phase_candidate!=BW_PHASE_FALL || point.phase_candidate_count!=1 || point.phase_id!=0)
      $fatal(1,"a changed trend cancels an unconfirmed ramp without creating a phase");
    #2000000;
    if(point.phase_candidate!=BW_PHASE_STEADY || point.phase_candidate_count!=1 ||
       point.phase_candidate_ticks!=8000000 || point.phase_candidate_total_bytes!=6 || point.phase_id!=0)
      $fatal(1,"a new stable candidate cannot inherit the unconfirmed fall's evidence count");
    #2000000;
    if(point.phase_current!=BW_PHASE_STEADY || point.phase_start_ticks!=8000001 ||
       point.phase_confirmation_ticks!=10000001 || point.phase_id!=1)
      $fatal(1,"only three consecutive stable candidates confirm the eventual phase");
    #(16000003-$time);
    if(point.phase_result_seq!=1 || point.phase_result.phase_kind!=BW_PHASE_STEADY ||
       point.phase_result.start_ticks!=8000001 || point.phase_result.end_ticks!=10250001 ||
       point.phase_result.start_total_bytes!=6 || point.phase_result.end_total_bytes!=6)
      $fatal(1,"unconfirmed ramp/fall candidates never become final phase intervals");
    $display("TB_PASS phase_candidate_change");$finish;
  end
endmodule
