module tb_episode_cycle;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] size_bytes=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  bw_point_mon #(.POINT_ID("episode.cycle"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(4),
    .UPDATE_STRIDE(2),.DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(3)) cycles
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(size_bytes),.size_known(1'b1));
  bw_point_mon #(.POINT_ID("episode.ns"),.WINDOW_WIDTH(20),.UPDATE_STRIDE(7),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(3)) physical
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(size_bytes),.size_known(1'b1));
  task automatic sample_at(bw_u64_t ticks,bit transfer,bw_u64_t bytes);
    #(ticks-$time);valid=transfer;size_bytes=bytes;clk=1;#1;clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    sample_at(10000000,1,16);sample_at(12000000,0,0);
    #(99000000-$time);
    if (!cycles.episode_active || cycles.episode_result_seq!=0 || cycles.result_seq!=0 ||
        physical.episode_active || physical.episode_result_seq!=1 ||
        physical.episode_result.confirmation_ticks!=15000000 ||
        physical.episode_result.duration_ticks!=2000000 || physical.episode_result.e2e_gbps!=8.0)
      $fatal(1,"ns silence advances during stop; cycle silence and held windows do not");
    sample_at(100000000,0,0);sample_at(101000000,0,0);sample_at(102000000,1,32);
    if (cycles.episode_result_seq!=1 || cycles.episode_result.confirmation_ticks!=102000000 ||
        cycles.episode_result.tail_ticks!=12000000 || cycles.episode_result.e2e_gbps!=8.0 ||
        !cycles.episode_active || cycles.episode_first_ticks!=102000000 || cycles.episode_tail_known)
      $fatal(1,"three actual quiet cycles finish the old episode before the deadline transfer");
    #(150000000-$time);
    if (!cycles.episode_active || !physical.episode_active || cycles.episode_tail_known ||
        physical.episode_tail_known || cycles.episode_result_seq!=1 || physical.episode_result_seq!=1)
      $fatal(1,"neither basis may invent a tail edge from an earlier clock period");
    sample_at(200000000,0,0);sample_at(201000000,0,0);sample_at(202000000,0,0);
    sample_at(203000000,0,0);
    if (cycles.episode_active || physical.episode_active || cycles.episode_result_seq!=2 ||
        physical.episode_result_seq!=2 || cycles.episode_result.duration_ticks!=98000000 ||
        physical.episode_result.duration_ticks!=98000000 ||
        cycles.episode_result.confirmation_ticks!=203000000 ||
        physical.episode_result.confirmation_ticks!=203000000 ||
        !cycles.episode_result.e2e_valid || !physical.episode_result.e2e_valid ||
        $abs(cycles.episode_result.e2e_gbps-0.32653061224489796)>1e-10 ||
        $abs(physical.episode_result.e2e_gbps-0.32653061224489796)>1e-10)
      $fatal(1,"the real 98ns tail cycle determines e2e independently of silence confirmation");
    $display("TB_PASS episode_cycle");$finish;
  end
endmodule
