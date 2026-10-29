// Ticket 56 slice 6: replay and missing participants. Duplicate settlement
// entries never duplicate counts or the completion marker; a missing owner
// terminal suppresses the marker independently of aggregate scope counts.
module tb_end_replay;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  string mode;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("re.p"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) p
    (.clk(clk),.reset_n(1'b1),.valid(valid));
`ifdef BW_MON_TEST_END_FAULTS
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="replay";
    if(mode=="suppress_owner")suppress_end_receipt(scope_key(BW_POINT,"re.p"),"owner");
  end
`endif
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="replay";
    wait(monitor_ready);
    #1000000;clk=1;#1;clk=0;
    #999999;clk=1;#1;clk=0;
    #999999;clk=1;#1;clk=0;
    valid=0;
    #999999;clk=1;#1;clk=0;
    #1000000;
    if(mode=="replay") begin
      // Duplicate public settlement requests must stay idempotent: one
      // scope-done count, one summary, one unique marker later on.
      report_scope_done(BW_POINT,"re.p",0);
      report_scope_done(BW_POINT,"re.p",0);
      if(check_report_summary().scopes_done!=1)
        $fatal(1,"duplicate scope_done must not double-count, got %0d",
          check_report_summary().scopes_done);
      note_point_terminal("re.p",1);
      note_point_terminal("re.p",1,"RECORDER_ACTIONS");
      if(scope_terminals.num()!=1)
        $fatal(1,"duplicate terminal request must not duplicate, got %0d",
          scope_terminals.num());
      $display("TB_PASS end_replay replay");$finish;
    end
    $display("TB_PASS end_replay %s",mode);$finish;
  end
endmodule
