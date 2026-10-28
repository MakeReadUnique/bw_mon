module tb_group_completion;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  string stage;
  bit damaged;
  bw_u64_t receipts[8],ticks[8],bytes[8];
  import "DPI-C" context function int bw_test_observe_group_completion();
  function void bw_test_group_completion_observed();
    if($time!=1000001 || scope_disabled(BW_POINT,"p") || scope_disabled(BW_GROUP,"peer") || peer.total_bytes!=8)
      $fatal(1,"original-time healthy peer differs");
    if(scope_disabled(BW_GROUP,"g0")!=damaged || scope_disabled(BW_GROUP,"g7")!=damaged)
      $fatal(1,"original-time hierarchy trust differs");
    if(!damaged)for(int g=0;g<8;g++)
      if(receipts[g]!=1 || ticks[g]!=1000001 || bytes[g]!=8)$fatal(1,"eight-layer receipt/value differs g%0d",g);
    if(retained_frame_count(p.transport_source)!=0)$fatal(1,"completed/cancelled input responsibilities leaked");
    $display("TB_GROUP_READ_ONLY ticks=%0d damaged=%0b peer_bytes=8",$time,damaged);
  endfunction
  export "DPI-C" function bw_test_group_completion_observed;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("p"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(8)) p
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("peer"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) peer(.clk(clk),.reset_n(1'b1));
  for(genvar g=0;g<8;g++)begin: groups
    bw_group_mon #(.GROUP_ID($sformatf("g%0d",g)),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) mon
      (.clk(clk),.reset_n(g==3?reset_n:1'b1));
    assign receipts[g]=mon.accepted_record_seq;assign ticks[g]=mon.raw_record.timestamp_ticks;
    assign bytes[g]=mon.raw_record.byte_inc;
  end
  initial begin
    if(!$value$plusargs("STAGE=%s",stage))stage="none";
    damaged=stage!="none" && stage!="notice";
    add_point_member("g0","p");add_point_member("peer","p");
    for(int g=1;g<8;g++)add_group_member($sformatf("g%0d",g),$sformatf("g%0d",g-1));
    wait(monitor_ready);
    if(stage!="none")inject_point_fault("g0",stage);
    #1000000;clk=1;
    if(!bw_test_observe_group_completion())$fatal(1,"cannot register read-only verifier");
    #1;clk=0;reset_n=0;
    #1000000;reset_n=1;clk=1;#1;
    if(scope_disabled(BW_GROUP,"peer") || peer.total_bytes!=16 || scope_disabled(BW_POINT,"p"))$fatal(1,"healthy peer/source did not continue");
    if(damaged && !scope_disabled(BW_GROUP,"g0"))$fatal(1,"reset revived failure");
    #10000000;
    if(scope_disabled(BW_GROUP,"peer"))$fatal(1,"stopped clock invented an edge");
    $display("TB_PASS group_completion stage=%s",stage);$finish;
  end
endmodule
