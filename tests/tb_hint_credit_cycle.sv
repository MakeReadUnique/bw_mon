module tb_hint_credit_cycle;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,flitv=0,lcrdv=0;
  bw_u64_t held_seq;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .SHORTAGE_ENABLE(1),.SHORTAGE_BASIS(BW_CYCLE),.SHORTAGE_THRESHOLD(1)) point
    (.clk(clk),.reset_n(1'b1),.flitv(flitv),.lcrdv(lcrdv));
  task automatic edge_at(bw_u64_t at_ticks,logic send_now,logic return_now);
    #(at_ticks-$time);flitv=send_now;lcrdv=return_now;clk=1;#1;clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    edge_at(1000000,0,0);held_seq=point.shortage_result_seq;
    #2999998;
    if(point.shortage_hit || point.shortage_duration_cycles!=0 || point.shortage_result_seq!=held_seq)
      $fatal(1,"credit cycle hint cannot advance during stopped clock");
    edge_at(4000000,0,1);
    if(!point.shortage_hit || point.shortage_active || point.shortage_duration_cycles!=1 ||
       point.shortage_trigger_ticks!=4000000 || point.shortage_end_reason!=BW_HINT_RELEASED)
      $fatal(1,"complete cycle must trigger before same-edge finalized credit return closes shortage");
    edge_at(5000000,1,0);
    if(!point.shortage_active || !point.shortage_cycle_anchor_valid || point.shortage_start_cycle!=3 ||
       point.shortage_start_ticks!=5000000 || point.shortage_duration_cycles!=0)
      $fatal(1,"late recorder ReNBA shortage start must still attach to actual current clock metadata");
    edge_at(6000000,0,1);
    if(point.shortage_active || !point.shortage_hit || point.shortage_hit_count!=2 ||
       point.shortage_duration_cycles!=1 || point.shortage_trigger_ticks!=6000000 || point.total_bytes!=8)
      $fatal(1,"new credit shortage cycle must not gain an extra cycle of hint latency");
    $display("TB_PASS hint_credit_cycle");$finish;
  end
endmodule
