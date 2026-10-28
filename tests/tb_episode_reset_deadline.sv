module tb_episode_reset_deadline;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,valid=0;
  logic [63:0] size_bytes=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("episode.reset_deadline"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(3)) point
    (.clk(clk),.reset_n(reset_n),.valid(valid),.size_bytes(size_bytes),.size_known(1'b1));
  task automatic sample_at(bw_u64_t ticks,bit transfer,bw_u64_t bytes);
    #(ticks+1-$time);valid=transfer;size_bytes=bytes;clk=1;#1;clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    sample_at(1000000,1,8);sample_at(2000000,0,0);
    #(5000002-$time);valid=1;size_bytes=128;clk=1;reset_n<=0;#1;clk=0;
    if (point.episode_result_seq!=1 || point.episode_result.status!=BW_EPISODE_RESET_INTERRUPTED ||
        point.episode_result.confirmation_ticks!=5000001 || point.episode_result.byte_count!=8 ||
        point.episode_result.stats_epoch!=0 || point.episode_result.e2e_valid ||
        point.stats_epoch!=1 || point.episode_active || point.total_bytes!=0 ||
        point.raw_record.record_seq!=3 || point.raw_record.byte_inc!=0 ||
        point.raw_record.event_inc!=0 || point.accepted_record_seq!=3)
      $fatal(1,"same-time NBA reset wins over old Q completion and the new raw transfer");
    #(6000002-$time);reset_n=1;valid=1;size_bytes=0;clk=1;#1;clk=0;
    sample_at(7000000,0,0);
    #(10000003-$time);
    if (point.episode_active || point.episode_result_seq!=2 || point.episode_result.episode_id!=2 ||
        point.episode_result.stats_epoch!=1 || !point.episode_result.e2e_valid ||
        point.episode_result.e2e_gbps!=0.0 || point.episode_result.byte_count!=0 ||
        point.episode_result.event_count!=1 || point.episode_result.duration_ticks!=1000000)
      $fatal(1,"a zero-byte transfer after reset is a complete new episode in its own statistics epoch");
    $display("TB_PASS episode_reset_deadline");$finish;
  end
endmodule
