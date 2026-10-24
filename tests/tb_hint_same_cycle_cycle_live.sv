module tb_hint_same_cycle_cycle_live;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,lcrdv=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),.CREDIT_ENABLE(1),
    .CREDIT_CAPACITY(1),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .CREDIT_RETURN_TIMING(BW_RETURN_SAME_CYCLE),.SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_CYCLE),
    .SHORTAGE_THRESHOLD(2)) point(.clk(clk),.reset_n(1'b1),.flitv(1'b0),.lcrdv(lcrdv));
  task automatic edge_at(bw_u64_t at_ticks);
    #(at_ticks-$time);lcrdv=0;clk=1;#1;clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    edge_at(1000000);edge_at(2000000);
    #(5500000-$time);lcrdv=1;#1;
    if(point.shortage_active || point.shortage_hit || point.shortage_duration_cycles!=1 ||
       point.shortage_end_reason!=BW_HINT_RELEASED || point.credit_balance!==64'd0)
      $fatal(1,"live SAME return must release a stopped cycle interval without adding a cycle or stored credit");
    #(6000000-$time);lcrdv=0;edge_at(7000000);
    #(8000000-$time);lcrdv=1'bx;#1;
    if(point.shortage_active || point.shortage_duration_cycles!=0 || point.shortage_trusted || !point.credit_trusted)
      $fatal(1,"unknown live return interrupts C0 cycle evidence without corrupting an unsampled ledger");
    #(9000000-$time);lcrdv=0;
    edge_at(10000000);edge_at(11000000);edge_at(12000000);
    if(!point.shortage_hit || point.shortage_duration_cycles!=2 || point.shortage_trigger_ticks!=12000000)
      $fatal(1,"new interval must accumulate two complete cycles after the unknown gap");
    #(12500000-$time);lcrdv=1;#1;
    if(point.shortage_active || point.shortage_hit_count!=1 || point.shortage_end_reason!=BW_HINT_RELEASED ||
       point.credit_shortage!==0 || !point.credit_shortage_known || point.credit_send_permitted!==0 ||
       !point.credit_permission_known || point.sampled_lcrdv!==0 || point.credit_balance!==64'd0 ||
       point.total_events!=0)
      $fatal(1,"current live usability is separate from last-frame permission and must not update ledger/event accounting");
    $display("TB_PASS hint_same_cycle_cycle_live");$finish;
  end
endmodule
