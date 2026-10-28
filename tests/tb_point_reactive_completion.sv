module tb_point_reactive_completion;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  bit kick=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("chain.point"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(8))
    p(.clk(clk),.reset_n(reset_n),.valid(1'b1));
  bw_point_mon #(.POINT_ID("chain.peer"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(16))
    q(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  import "DPI-C" context function int bw_test_observe_point_completion();
  function void bw_test_point_completion_observed();
    if($time!=1000001 || p.total_bytes!=0 || q.total_bytes!=16 || p.stats_epoch!=20 ||
       scope_disabled(BW_POINT,"chain.point") || !point_batch_complete("chain.point") || !point_batch_complete("chain.peer"))
      $fatal(1,"finite same-time reset chain must close without transient missing or changed timestamps");
    $display("TB_PASS point_reactive_completion original_ticks=%0d assertions=20 peer_bytes=16",$time);
    $finish;
  endfunction
  export "DPI-C" function bw_test_point_completion_observed;
  point_completion_driver driver();
  initial begin
    wait(monitor_ready);#1000000;clk=1;kick<=1;
    if(!bw_test_observe_point_completion())$fatal(1,"cannot register read-only chain verdict");
  end
endmodule
program point_completion_driver;
  timeunit 1fs;timeprecision 1fs;
  initial begin
    @(posedge tb_point_reactive_completion.kick);
    repeat(20)begin
      tb_point_reactive_completion.reset_n<=0;
      @(tb_point_reactive_completion.reset_n);#0;
      tb_point_reactive_completion.reset_n<=1;
      @(tb_point_reactive_completion.reset_n);#0;
    end
  end
endprogram
