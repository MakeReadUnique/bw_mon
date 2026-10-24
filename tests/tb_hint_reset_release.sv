module tb_hint_reset_release;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=0,flitv=1,lcrdv=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(2),.CREDIT_INITIAL(1),.CREDIT_INITIAL_KNOWN(1),
    .SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_CYCLE),.SHORTAGE_THRESHOLD(1)) point
    (.clk(clk),.reset_n(reset_n),.flitv(flitv),.lcrdv(lcrdv));
  initial begin
    wait(monitor_ready);
    #1000000;clk=1;reset_n<=1;#1;clk=0;
    if(point.sampled_reset_n!==0 || point.raw_record.event_inc!=0 || point.total_bytes!=0 ||
       !point.credit_trusted || point.credit_balance!==64'd1 || point.shortage_active)
      $fatal(1,"reset-held sampled frame must not debit a send or invent shortage when live reset releases later that T");
    #999999;clk=1;#1;clk=0;
    if(point.total_bytes!=8 || point.credit_balance!==64'd0 || !point.shortage_active ||
       point.shortage_start_ticks!=2000000 || point.shortage_start_cycle!=2)
      $fatal(1,"first genuinely released transfer must debit credit and start shortage at its actual edge");
    #999999;flitv=0;lcrdv=1;clk=1;#1;
    if(point.total_bytes!=8 || !point.shortage_hit || point.shortage_active ||
       point.shortage_trigger_ticks!=3000000 || point.shortage_duration_cycles!=1 ||
       point.shortage_end_reason!=BW_HINT_RELEASED || point.credit_balance!==64'd1)
      $fatal(1,"next finalized return closes one complete shortage cycle after reset recovery");
    $display("TB_PASS hint_reset_release");$finish;
  end
endmodule
