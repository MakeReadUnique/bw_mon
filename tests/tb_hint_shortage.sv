module tb_hint_shortage;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,flitv=0,lcrdv=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(3)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_NS),.SHORTAGE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(1'b1),.flitv(flitv),.lcrdv(lcrdv));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1)) disabled
    (.clk(clk),.reset_n(1'b1),.flitv(flitv),.lcrdv(lcrdv));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL_KNOWN(0),
    .SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_NS),.SHORTAGE_THRESHOLD(2)) untrusted
    (.clk(clk),.reset_n(1'b1),.flitv(flitv),.lcrdv(lcrdv));
  task automatic edge_now();clk=1;#1;clk=0;endtask
  initial begin
    wait(monitor_ready);
    #2000001;
    if(!point.shortage_hit || point.shortage_trigger_ticks!=2000000 || point.shortage_hit_count!=1 ||
       !point.credit_trusted || point.total_bytes!=0)
      $fatal(1,"known zero-credit condition can persist without demand or sampling clocks");
    #999999;lcrdv=1'bx;#1;
    if(point.shortage_active || point.shortage_trusted || point.shortage_end_reason!=BW_HINT_UNKNOWN ||
       point.shortage_duration_ticks!=3000000 || !point.credit_trusted)
      $fatal(1,"live unknown return must break ns hint evidence during stopped clock, without inventing a sampled ledger event");
    #999999;lcrdv=0;
    #1000000;lcrdv=1;edge_now();
    if(point.shortage_active || point.shortage_end_reason!=BW_HINT_RELEASED ||
       point.shortage_duration_ticks!=1000000 || point.shortage_hit || point.credit_balance!==64'd1)
      $fatal(1,"real sampled credit return must end shortage using finalized shared sample");
    #999999;lcrdv=0;flitv=1;edge_now();
    #1999999;flitv=1'bx;#1;
    if(point.shortage_active || !point.shortage_hit || point.shortage_hit_count!=2 ||
       point.shortage_trigger_ticks!=8000000 || point.shortage_end_reason!=BW_HINT_UNKNOWN)
      $fatal(1,"threshold-equal raw unknown must retain preceding complete shortage interval hit");
    #999999;flitv=1;
    #1000000;edge_now();
    if(point.credit_trusted || point.shortage_active || point.shortage_trusted ||
       point.shortage_end_reason!=BW_HINT_UNKNOWN || point.shortage_hit || point.shortage_duration_ticks!=1000000 ||
       point.total_bytes!=16 || disabled.total_bytes!=16 || point.total_events!=disabled.total_events ||
       !point.raw_record.bytes_complete)
      $fatal(1,"ledger anomaly stops shortage evidence while definite flit bytes remain identical with hints disabled");
    #1000000;
    if(point.shortage_hit_count!=2 || disabled.shortage_hit_count!=0 ||
       point.window_bytes!=disabled.window_bytes || point.bytes_complete!=disabled.bytes_complete ||
       untrusted.shortage_active || untrusted.shortage_trusted || untrusted.shortage_hit_count!=0 ||
       untrusted.shortage_interval_count!=0 || untrusted.total_bytes!=16 || !$isunknown(untrusted.credit_balance))
      $fatal(1,"stale ledger/window snapshots cannot extend or retrigger hint intervals");
    $display("TB_PASS hint_shortage");$finish;
  end
endmodule
