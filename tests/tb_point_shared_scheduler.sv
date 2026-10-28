module tb_point_shared_scheduler;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("shared.p"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(8))
    p(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_point_mon #(.POINT_ID("shared.q"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(16))
    q(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  initial begin
    wait(monitor_ready);#1000000;bw_native_fail_slot_registration();clk=1;
    #1;
    if(!monitoring_shared_disabled || !scope_disabled(BW_POINT,"shared.p") || !scope_disabled(BW_POINT,"shared.q") ||
       p.accepted_record_seq!=0 || q.accepted_record_seq!=0)
      $fatal(1,"failed shared scheduler must stop all scopes before accepting damaged work");
    $display("TB_PASS point_shared_scheduler all_disabled=1 accepted=0");$finish;
  end
endmodule
