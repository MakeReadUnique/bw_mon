module tb_group_public_pressure;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  logic [63:0] size_bytes=8;
  bit kick=0,checked=0;
  bw_u64_t receipts[16];
  bw_test_consumer_gate gate;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("p"),.DYNAMIC_BYTES(1),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(16),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1)) p
    (.clk(clk),.reset_n(reset_n),.valid(1'b1),.size_bytes(size_bytes),.size_known(1'b1));
  bw_group_mon #(.GROUP_ID("shared"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(16),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1)) shared
    (.clk(clk),.reset_n(1'b1));
  for(genvar g=0;g<16;g++)begin: parents
    bw_group_mon #(.GROUP_ID($sformatf("parent%0d",g)),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(16),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1)) mon
      (.clk(clk),.reset_n(1'b1));
    assign receipts[g]=mon.accepted_record_seq;
  end
  import "DPI-C" context function int bw_test_observe_group_completion();
  function void bw_test_group_completion_observed();
    if($time!=2750001 || !checked || shared.accepted_record_seq!=6 || shared.total_bytes!=56 || shared.total_events!=5 || shared.core.history.size()<4)
      $fatal(1,"public original-time history/raw/core evidence differs");
    for(int g=0;g<16;g++)if(receipts[g]!=6 || scope_disabled(BW_GROUP,$sformatf("parent%0d",g)))$fatal(1,"public parent%0d did not complete",g);
    if(retained_frame_count(shared.transport_source)!=0 || retained_control_count(shared.transport_source)!=0 || retained_frame_count(p.transport_source)!=0)
      $fatal(1,"public same-time all-effective-ACK release differs");
    $display("TB_PASS group_public_pressure original_ticks=%0d consumers=16 history_segments=%0d raw_total=56 events=5 held_frame=1 controls=2 release=0",$time,shared.core.history.size());$finish;
  endfunction
  export "DPI-C" function bw_test_group_completion_observed;
  initial begin
    add_point_member("shared","p");
    for(int g=0;g<16;g++)add_group_member($sformatf("parent%0d",g),"shared");
    wait(monitor_ready);#250000;
    for(int i=1;i<=6;i++)begin
      size_bytes=(i%2)?8:16;
      if(i==6)begin
        gate=bw_test_gate_for("parent15");gate.resume_after_seq=6;
        for(int g=0;g<15;g++)gate.resume_after_groups.push_back($sformatf("parent%0d",g));
        gate.paused=1;kick<=1;
      end
      clk=1;
      if(i==6 && !bw_test_observe_group_completion())$fatal(1,"cannot register public pressure nativeRO verifier");
      #1;clk=0;#499999;
    end
  end
  task automatic observe();
    wait(kick);
    for(int g=0;g<15;g++)wait(group_batches[$sformatf("parent%0d",g)].acked==6);
    if($time!=2750001 || !gate.paused || group_batches["parent15"].acked!=5 || shared.core.history.size()<4 ||
       retained_frame_count(shared.transport_source)!=1 || retained_control_count(shared.transport_source)!=2 || acknowledged_frame_seq(shared.group_handle,0)!=6 ||
       retained_frame_count(p.transport_source)!=0 || shared.accepted_record_seq!=6 || shared.control_result_seq!=3)
      $fatal(1,"public16-parent same-time hold/read/core/ACK/history coupling differs");
    checked=1;$display("TB_PUBLIC_PRESSURE_PEAK original_ticks=%0d fast_ack=6 slow_ack=5 frames=1 controls=2 history=%0d",$time,shared.core.history.size());
  endtask
  public_pressure_observer observer();
  public_pressure_reset driver();
endmodule
program public_pressure_observer;
  initial tb_group_public_pressure.observe();
endprogram
program public_pressure_reset;
  initial begin
    @(posedge tb_group_public_pressure.kick);
    tb_group_public_pressure.reset_n<=0;
    @(tb_group_public_pressure.reset_n);#0;
    tb_group_public_pressure.reset_n<=1;
  end
endprogram
