module tb_group_cycle_quality;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,ready=1;
  logic [63:0] size_bytes=8;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("hs"),.PROTOCOL(BW_VALID_READY),.DYNAMIC_BYTES(1),
    .WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) hs
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.ready(ready),.size_bytes(size_bytes),.size_known(1'b1));
  bw_point_mon #(.POINT_ID("flit"),.PROTOCOL(BW_CREDIT),.FIXED_BYTES(16),
    .WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) flit
    (.clk(clk),.reset_n(1'b1),.flitv(1'b1),.lcrdv(1'bx));
  bw_group_mon #(.GROUP_ID("cycle.quality"),.WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) group_mon (.clk(clk),.reset_n(1'b1));
  task automatic sample(bw_u64_t ticks,logic ready_now,logic [63:0] bytes_now);
    #(ticks-$time-1);ready=ready_now;size_bytes=bytes_now;
    #1;clk=1;#1;clk=0;
  endtask
  initial begin
    add_point_member("cycle.quality","hs");add_point_member("cycle.quality","flit");
    wait(monitor_ready);
    sample(250000,1,8);sample(750000,1,0);
    if(group_mon.window_bytes!=24 || group_mon.coverage_cycles!=1 || !group_mon.window_warmup ||
       group_mon.raw_record.byte_inc!=16 || group_mon.raw_record.event_inc!=2 ||
       $abs(group_mon.bandwidth_gbps-48.0)>1e-10)
      $fatal(1,"cycle warmup/zero-byte activity differs from raw edge table");
    sample(1250000,1,'x);
    if(group_mon.window_bytes!=40 || !group_mon.window_valid || group_mon.raw_record.bytes_complete ||
       !group_mon.raw_record.events_complete || group_mon.raw_record.event_inc!=2)
      $fatal(1,"current unknown size must preserve events and remain outside the right endpoint");
    sample(1750000,1'bx,8);
    if(group_mon.window_bytes!=32 || group_mon.window_events!=4 || group_mon.bytes_complete ||
       !group_mon.events_complete || group_mon.raw_record.events_complete || group_mon.raw_record.event_inc!=1)
      $fatal(1,"known group contributions and byte/event quality must remain separate");
    sample(2250000,0,'x);
    if(group_mon.window_bytes!=32 || group_mon.window_events!=3 || group_mon.bytes_complete ||
       group_mon.events_complete || !group_mon.raw_record.bytes_complete || !group_mon.raw_record.events_complete)
      $fatal(1,"known idle ignores unused X size while old unknown observations remain in window");
    sample(2750000,1,8);sample(3250000,1,8);
    if(group_mon.window_bytes!=40 || group_mon.window_events!=3 || !group_mon.window_valid ||
       !group_mon.events_complete || group_mon.result_seq!=6 || group_mon.total_bytes!=136 ||
       group_mon.total_events!=12 || $abs(group_mon.bytes_per_cycle-20.0)>1e-10)
      $fatal(1,"group quality must recover when old unknown positions expire exactly");
    #(10000002-$time);
    if(group_mon.result_seq!=6 || group_mon.window_end_ticks!=3250001 || group_mon.window_bytes!=40)
      $fatal(1,"cycle group must hold original snapshot and sequence throughout clock stop");
    sample(10250000,1,8);
    if(group_mon.result_seq!=7 || group_mon.window_start_ticks!=2750001 ||
       group_mon.window_end_ticks!=10250001 || group_mon.window_bytes!=48 ||
       group_mon.window_events!=4 || $abs(group_mon.bandwidth_gbps-6.4)>1e-10 ||
       $abs(group_mon.bytes_per_cycle-24.0)>1e-10 || group_mon.total_bytes!=160 ||
       group_mon.total_events!=14 || !group_mon.window_valid || group_mon.accepted_record_seq!=8)
      $fatal(1,"resumed group GB/s must use actual elapsed time, with independent B/cycle");
    $display("TB_PASS group_cycle_quality");$finish;
  end
endmodule
