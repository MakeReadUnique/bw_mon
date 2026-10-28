module tb_point_completion;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_p=1;
  string stage;
  bit damaged;
  import "DPI-C" context function int bw_test_observe_point_completion();
  function void bw_test_point_completion_observed();
    if($time!=1000001 || scope_disabled(BW_POINT,"damaged")!=damaged ||
       scope_disabled(BW_POINT,"healthy") || q.total_bytes!=16)
      $fatal(1,"read-only original-time verdict differs from independent input expectation");
    if(!damaged && (p.total_bytes!=8 || !point_batch_complete("damaged")))
      $fatal(1,"read-only verdict lacks durable point completion");
    $display("TB_READ_ONLY_CLOSURE ticks=%0d damaged=%0b healthy_bytes=%0d",$time,damaged,q.total_bytes);
  endfunction
  export "DPI-C" function bw_test_point_completion_observed;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("damaged"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(8))
    p(.clk(clk),.reset_n(reset_p),.valid(1'b1));
  bw_point_mon #(.POINT_ID("healthy"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(16))
    q(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  initial begin
    if(!$value$plusargs("STAGE=%s",stage))stage="capture";
    damaged=stage!="notice" && stage!="none";
    wait(monitor_ready);
    if(stage!="none")inject_point_fault("damaged",stage);
    #1000000;clk=1;
    if(!bw_test_observe_point_completion())$fatal(1,"cannot register read-only verdict");
    // The runner independently requires the diagnostic at 1000001fs. A
    // detector delayed until the following fs cannot satisfy that oracle.
    #1;
    if(scope_disabled(BW_POINT,"damaged")!=damaged)$fatal(1,"point trust state does not match completed edge");
    if(q.total_bytes!=16)$fatal(1,"healthy point failed real edge");
    if(!damaged && p.total_bytes!=8)$fatal(1,"complete durable receipts must survive a lost notice");
    clk=0;reset_p=0;
    #1000000;reset_p=1;clk=1;
    #1;
    if(q.total_bytes!=32)$fatal(1,"healthy point did not continue");
    if(damaged && !scope_disabled(BW_POINT,"damaged"))$fatal(1,"reset revived disabled point");
    // No new edge exists during the stopped clock. None may be invented.
    #10000000;
    if(scope_disabled(BW_POINT,"healthy"))$fatal(1,"stopped clock was treated as missing input");
    clk=0;#3212345;clk=1;#1;
    if(q.total_bytes!=48 || scope_disabled(BW_POINT,"healthy"))$fatal(1,"resumed changed-period clock must accept only its real edge");
    if(!damaged && p.total_bytes!=24)$fatal(1,"reliable point lost the resumed edge");
    $display("TB_PASS point_completion stage=%s healthy_bytes=48",stage);$finish;
  end
endmodule
