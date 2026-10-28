module tb_group_timer_completion;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("g0"),.WINDOW_WIDTH(1),.FIXED_BYTES(8)) p(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("peer"),.WINDOW_WIDTH(1)) peer(.clk(clk),.reset_n(1'b1));
  for(genvar g=0;g<8;g++)begin: groups
    bw_group_mon #(.GROUP_ID($sformatf("g%0d",g)),.WINDOW_WIDTH(1)) mon(.clk(clk),.reset_n(1'b1));
  end
  import "DPI-C" context function int bw_test_observe_group_completion();
  function void bw_test_group_completion_observed();
    if($time!=1000001 || !scope_disabled(BW_GROUP,"g0") || !scope_disabled(BW_GROUP,"g7") ||
       scope_disabled(BW_POINT,"g0") || scope_disabled(BW_GROUP,"peer") || p.result_seq!=1 || peer.result_seq!=1 || peer.window_bytes!=8 ||
       group_batches["g0"].expected!=1 || point_batches["g0"].expected!=1)
      $fatal(1,"due timer receipt failure must isolate its group path at original time without inventing clock edges");
    if(monitoring_root_cause[scope_key(BW_GROUP,"g7")]!=scope_key(BW_GROUP,"g0"))$fatal(1,"timer failure lost typed root");
    $display("TB_PASS group_timer_completion original_ticks=%0d expected_edges=1 healthy_window=8",$time);$finish;
  endfunction
  export "DPI-C" function bw_test_group_completion_observed;
  initial begin
    add_point_member("g0","g0");add_point_member("peer","g0");
    for(int g=1;g<8;g++)add_group_member($sformatf("g%0d",g),$sformatf("g%0d",g-1));
    wait(monitor_ready);#250000;clk=1;#1;clk=0;
    inject_group_fault("g0","timer_core");
    #(measurement_start_ticks+1000000-$time);
    if(!bw_test_observe_group_completion())$fatal(1,"cannot register timer nativeRO verifier");
  end
endmodule
