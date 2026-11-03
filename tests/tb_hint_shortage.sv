module tb_hint_shortage;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,flitv=0,lcrdv=0;
  bw_mon_setup setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_NS),.SHORTAGE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(reset_n),.flitv(flitv),.lcrdv(lcrdv));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1)) disabled
    (.clk(clk),.reset_n(reset_n),.flitv(flitv),.lcrdv(lcrdv));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL_KNOWN(0),
    .SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_NS),.SHORTAGE_THRESHOLD(2)) untrusted
    (.clk(clk),.reset_n(reset_n),.flitv(flitv),.lcrdv(lcrdv));
  task automatic edge_now();clk=1;#1;clk=0;endtask
  initial begin
    wait(monitor_ready);
    #2000001;
    if(!point.shortage_hit || point.shortage_trigger_ticks!=2000001 || point.shortage_hit_count!=1 ||
       !point.credit_trusted || point.total_bytes!=0)
      $fatal(1,"known zero usable credit can persist without demand or sampling clocks");
    #999999;lcrdv=1'bx;#1;
    if(!point.shortage_active || !point.shortage_trusted || !point.credit_shortage_known ||
       point.credit_shortage!==1 || !point.credit_trusted)
      $fatal(1,"NEXT mode uses known stored C until an actual sampled return update");
    #499999;edge_now();
    if(point.credit_trusted || point.shortage_active || point.shortage_end_reason!=BW_HINT_UNKNOWN ||
       point.shortage_duration_ticks!=3500000 || !point.raw_record.bytes_complete)
      $fatal(1,"sampled unknown return loses ledger trust while definite idle remains known");
    #499999;reset_n=0;lcrdv=0;#250000;reset_n=1;
    #750000;lcrdv=1;edge_now();
    if(point.shortage_active || point.shortage_end_reason!=BW_HINT_RELEASED ||
       point.shortage_duration_ticks!=750000 || point.shortage_hit || point.credit_balance!==64'd1)
      $fatal(1,"finalized NEXT-cycle return ends fresh shortage using the actual shared sample");
    #999999;lcrdv=0;flitv=1;edge_now();
    #1999999;flitv=1'bx;#1;
    if(!point.shortage_active || !point.shortage_hit || point.shortage_hit_count!=2 ||
       point.shortage_trigger_ticks!=8000001 || !point.shortage_trusted)
      $fatal(1,"off-edge send uncertainty does not change known usable credits or infer demand");
    #499999;edge_now();
    if(point.credit_trusted || point.shortage_active || point.shortage_end_reason!=BW_HINT_UNKNOWN ||
       point.shortage_duration_ticks!=2500000 || !point.shortage_hit || point.raw_record.events_complete)
      $fatal(1,"sampled unknown send interrupts ledger trust and the prior known shortage interval");
    #499999;reset_n=0;flitv=1;#250000;reset_n=1;
    #750000;edge_now();
    if(point.credit_trusted || point.shortage_active || point.shortage_trusted ||
       point.shortage_end_reason!=BW_HINT_UNKNOWN || point.shortage_hit || point.shortage_duration_ticks!=750000 ||
       point.total_bytes!=8 || disabled.total_bytes!=8 || point.total_events!=disabled.total_events ||
       !point.raw_record.bytes_complete)
      $fatal(1,"no-credit send stops shortage evidence while definite bytes match disabled point after local reset");
    #1000000;
    if(point.shortage_hit_count!=2 || disabled.shortage_hit_count!=0 ||
       point.window_bytes!=disabled.window_bytes || point.bytes_complete!=disabled.bytes_complete ||
       untrusted.shortage_active || untrusted.shortage_trusted || untrusted.shortage_hit_count!=0 ||
       untrusted.shortage_interval_count!=0 || untrusted.total_bytes!=8 || !$isunknown(untrusted.credit_balance))
      $fatal(1,"unknown ledger cannot invent shortage and held snapshots cannot retrigger intervals");
    $display("TB_PASS hint_shortage");$finish;
  end
endmodule
