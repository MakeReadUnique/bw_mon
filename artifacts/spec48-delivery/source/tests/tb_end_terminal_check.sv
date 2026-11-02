// Ticket 56 slice 5: audit-authorized terminal default settlement. A
// finalized reliable FAIL survives a later disable; the still-active episode
// of the disabled owner is settled once from frozen submitted evidence (one
// warning when its own platform never confirmed). An analysis-disabled scope
// stays STATISTICS_ONLY. Every settlement precedes the summary and the unique
// report-completion marker.
module tb_end_terminal_check;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0,off_valid=0;
  logic [63:0] bytes=100;
  string mode;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("t.active"),.WINDOW_WIDTH(1),.DYNAMIC_BYTES(1),
    .EPISODE_ENABLE(1)) p(.clk(clk),.reset_n(1'b1),.valid(valid),
    .size_known(1'b1),.size_bytes(bytes));
  bw_point_mon #(.POINT_ID("t.off"),.WINDOW_WIDTH(1),.FIXED_BYTES(8),
    .EPISODE_ENABLE(1),.PHASE_ENABLE(0)) off
    (.clk(clk),.reset_n(1'b1),.valid(off_valid));
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="fail_active";
    wait(monitor_ready);
    if(mode=="stats_only") begin
      // An analysis-disabled scope never produces default checks; the
      // summary stays STATISTICS_ONLY and the report still completes.
      for(int update=1;update<=6;update++)begin
        off_valid=1;
        #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
        #(measurement_start_ticks+update*1000000+1-$time);
      end
      #2000000;
      $display("TB_PASS end_terminal stats_only");$finish;
    end
    if(mode=="no_platform") begin
      // Five alternating windows cannot confirm a platform; the terminal
      // settlement must produce exactly one episode warning.
      for(int update=1;update<=5;update++)begin
        valid=1;bytes=update%2 ? 92 : 108;
        #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
        #(measurement_start_ticks+update*1000000+1-$time);
      end
      runtime_scope_error(BW_POINT,"t.active","TEST_FAULT",
        "fixture stops the platformless prefix before any confirmation");
      #2000000;
      $display("TB_PASS end_terminal no_platform");$finish;
    end
    // fail_active: episode 1 confirms a platform and settles a reliable
    // FAIL; episode 2 is still active when monitoring stops.
    for(int update=1;update<=60;update++)begin
      valid=update<=24 || (update>=41 && update<=60);
      bytes=update%2 ? 92 : 108;
      #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
      #(measurement_start_ticks+update*1000000+1-$time);
    end
    runtime_scope_error(BW_POINT,"t.active","TEST_FAULT",
      "fixture stops monitoring while the second episode is active");
    #2000000;
    $display("TB_PASS end_terminal fail_active");$finish;
  end
endmodule
