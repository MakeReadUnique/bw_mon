module tb_point_finish;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  string mode;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("finish.point"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(8))
    p(.clk(clk),.reset_n(reset_n),.valid(1'b1));
  import "DPI-C" context function int bw_test_observe_point_completion();
  function void bw_test_point_completion_observed();
    if($time!=1000001 || p.total_bytes!=8 || !point_batch_complete("finish.point") || scope_disabled(BW_POINT,"finish.point"))
      $fatal(1,"original-time normal-finish target generation incomplete");
    $display("TB_PASS point_finish normal original_ticks=%0d bytes=8",$time);$finish;
  endfunction
  export "DPI-C" function bw_test_point_completion_observed;
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="immediate";
    wait(monitor_ready);#1000000;
    if(mode=="control")reset_n=0;
    else clk=1;
    if(mode=="normal")begin
      if(!bw_test_observe_point_completion())$fatal(1,"cannot register original-time finish observer");
    end else begin
      $display("TB_PASS point_finish %s original_ticks=%0d",mode,$time);$finish;
    end
  end
endmodule
