module tb_group_control_completion;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  bit drop_recovery=0;
  bw_u64_t controls[8];
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("p"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) p(.clk(clk),.reset_n(reset_n),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("peer"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) peer(.clk(clk),.reset_n(1'b1));
  for(genvar g=0;g<8;g++)begin: groups
    bw_group_mon #(.GROUP_ID($sformatf("g%0d",g)),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) mon(.clk(clk),.reset_n(1'b1));
    assign controls[g]=mon.control_result_seq;
  end
  import "DPI-C" context function int bw_test_observe_group_completion();
  function void bw_test_group_completion_observed();
    if($time!=1000001 || scope_disabled(BW_POINT,"p") || peer.control_result_seq!=2 || p.stats_epoch!=1)
      $fatal(1,"raw no-edge point reset or reliable sibling differs");
    for(int g=0;g<8;g++)begin
      if(controls[g]!=(drop_recovery?1:2) || scope_disabled(BW_GROUP,$sformatf("g%0d",g))!=drop_recovery || group_batches[$sformatf("g%0d",g)].expected!=0 ||
         (!drop_recovery && !group_batch_complete($sformatf("g%0d",g))) || (drop_recovery && !group_batches[$sformatf("g%0d",g)].cancelled))
        $fatal(1,"durable no-edge control must recover lost advisory wake at original time g%0d",g);
    end
    if(retained_control_count(p.transport_source)!=0 || retained_control_count(groups[0].mon.transport_source)!=0)
      $fatal(1,"control-only completion leaked responsibility");
    $display("TB_PASS group_control_completion original_ticks=%0d controls=2 frames=0 wake_recovered=%0b",$time,!drop_recovery);$finish;
  endfunction
  export "DPI-C" function bw_test_group_completion_observed;
  initial begin
    add_point_member("g0","p");add_point_member("peer","p");
    for(int g=1;g<8;g++)add_group_member($sformatf("g%0d",g),$sformatf("g%0d",g-1));
    drop_recovery=$test$plusargs("DROP_RECOVERY");
    wait(monitor_ready);#1000000;
    inject_group_fault("g0","input_notice");
    if(drop_recovery)inject_group_fault("g0","collector_recovery");
    reset_n=0;
    if(!bw_test_observe_group_completion())$fatal(1,"cannot register control nativeRO verifier");
  end
endmodule
