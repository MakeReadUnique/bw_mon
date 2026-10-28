module tb_settle_phase_renba;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  int mode=0,late_confirmations=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("settle.phase"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),.FIXED_BYTES(8),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(5),.PHASE_ENABLE(1),.PHASE_N(3),
    .PHASE_MIN_SPAN(2),.PHASE_K(1),
    .PHASE_STEADY_ENTER_ABS(0),.PHASE_STEADY_ENTER_REL(0),
    .PHASE_STEADY_EXIT_ABS(0),.PHASE_STEADY_EXIT_REL(0),
    .PHASE_RMS_ENTER_ABS(0),.PHASE_RMS_ENTER_REL(0),
    .PHASE_RMS_EXIT_ABS(0),.PHASE_RMS_EXIT_REL(0),
    .PHASE_TREND_ABS(1),.PHASE_TREND_REL(0)) point
    (.clk(clk),.reset_n(reset_n),.valid(1'b1));
  settle_phase_renba_driver driver();
  always @(point.phase_id)
    if($time==3000000 && point.phase_id!=0)late_confirmations++;
  initial begin
    void'($value$plusargs("MODE=%d",mode));wait(monitor_ready);
    for(int n=0;n<6;n++)begin #(250000+n*500000-$time);clk=1;#1;clk=0;end
    #(3000002-$time);if(mode==0)reset_n<=0;
    #1;
    if(point.stats_epoch!=1 || point.result_seq!=2 || point.phase_id!=0 ||
       point.phase_result_seq!=0 || late_confirmations!=0 ||
       point.episode_result_seq!=1 || point.episode_result.status!=BW_EPISODE_RESET_INTERRUPTED ||
       point.episode_result.stats_epoch!=0 || point.episode_result.episode_id!=1 ||
       point.episode_result.first_ticks!=250001 || point.episode_result.last_ticks!=2750001 ||
       point.episode_result.byte_count!=48 || point.episode_result.event_count!=6 ||
       point.episode_result.tail_known || point.episode_result.duration_valid ||
       point.episode_result.e2e_valid || point.episode_result.last_steady_found)
      $fatal(1,"reset at third full sample must prevent phase confirmation/formal fragment before clearing");
    $display("TB_PASS settle_phase_renba mode=%0d",mode);$finish;
  end
endmodule
program settle_phase_renba_driver;
  timeunit 1fs;timeprecision 1fs;
  initial begin
    wait(bw_mon_pkg::monitor_ready);#3000000;
    if(tb_settle_phase_renba.mode==1)tb_settle_phase_renba.reset_n<=0;
  end
endprogram
