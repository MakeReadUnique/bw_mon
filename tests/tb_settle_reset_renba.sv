module tb_settle_reset_renba;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  int mode=0,old_publications=0;
  bit observed_failure=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("audit.renba"),.WINDOW_WIDTH(2),
    .UPDATE_STRIDE(1),.FIXED_BYTES(8)) point
    (.clk(clk),.reset_n(reset_n),.valid(1'b1));
  settle_reset_renba_driver driver();
  always @(point.result_seq)
    if($time==2000000 && point.result_seq>1)old_publications++;
  initial begin
    void'($value$plusargs("MODE=%d",mode));
    if(!(mode inside {0,1}))$fatal(1,"PROBE_BAD_MODE");
    wait(monitor_ready);
    #250000;clk=1;#1;clk=0;
    #499999;clk=1;#1;clk=0;
    #(2000002-$time);
    if(mode==0)reset_n<=0;
    #1;
    $display("PROBE_VALUES mode=%s read_ticks=%0d expected_seq=1 actual_seq=%0d expected_epoch=1 actual_epoch=%0d expected_reset=0 actual_reset=%b expected_publications=0 actual_publications=%0d expected_bytes=0 actual_bytes=%0d expected_denominator=0 actual_denominator=%b",
      mode==0?"moduleNBA":"programReNBA",$time,point.result_seq,point.stats_epoch,
      reset_n,old_publications,point.total_bytes,point.denominator_valid);
    observed_failure=(point.stats_epoch!=1 || point.result_seq!=1 || old_publications!=0 ||
      reset_n!==1'b0 || point.total_bytes!=0 || point.denominator_valid);
    if(observed_failure)$display("PROBE_FAIL mode=%s",mode==0?"moduleNBA":"programReNBA");
    else $display("PROBE_PASS mode=%s",mode==0?"moduleNBA":"programReNBA");
    #(8000002-$time);
    if(observed_failure)$fatal(1,"PREFLIGHT_RENBA_RESET_PUBLICATION");
    $display("TB_PASS settle_reset_renba mode=%0d",mode);$finish;
  end
endmodule

program settle_reset_renba_driver;
  timeunit 1fs;timeprecision 1fs;
  initial begin
    wait(bw_mon_pkg::monitor_ready);
    #2000000;
    if(tb_settle_reset_renba.mode==1)tb_settle_reset_renba.reset_n<=0;
  end
endprogram
