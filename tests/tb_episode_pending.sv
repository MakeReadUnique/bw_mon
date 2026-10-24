module tb_episode_pending;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_record_t frame='0;
  bit frame_toggle=0;
  logic reset_n=1;
  bw_u64_t watermark=BW_U64_MAX,accepted,final_seq,window_end,epoch;
  bit active;
  int mode=0,handle;
  bw_episode_result_t result;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_stats_core #(.WINDOW_WIDTH(4),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) core
    (.scope_id("episode.pending"),.scope_kind(BW_GROUP),.record(frame),.record_toggle(frame_toggle),
     .stats_reset_n(reset_n),.progress_watermark_ticks(watermark),.accepted_record_seq(accepted),
     .episode_active(active),.episode_result_seq(final_seq),.episode_result(result),
     .window_end_ticks(window_end),.stats_epoch(epoch),
     .member_control('0),.member_control_toggle(1'b0),.accepted_control_count(),
     .result_seq(),.total_bytes(),.total_events(),
     .window_start_ticks(),.window_start_cycle(),.window_end_cycle(),
     .coverage_ticks(),.coverage_cycles(),.window_bytes(),
     .window_events(),.bandwidth_gbps(),.bytes_per_cycle(),
     .window_warmup(),.window_full(),.bytes_complete(),
     .events_complete(),.denominator_valid(),.window_valid(),
     .member_reset_coverage(),.episode_status(),.episode_id(),
     .episode_first_ticks(),.episode_last_ticks(),.episode_tail_ticks(),
     .episode_confirmation_ticks(),.episode_first_cycle(),.episode_last_cycle(),
     .episode_tail_cycle(),.episode_bytes(),.episode_events(),
     .episode_duration_ticks(),.episode_first_known(),.episode_last_known(),
     .episode_tail_known(),.episode_bytes_complete(),.episode_events_complete(),
     .episode_member_reset_coverage(),.episode_duration_valid(),.episode_e2e_valid(),
     .episode_e2e_gbps());
  task automatic deliver(bw_u64_t logical_tick,bw_u64_t edge_number,bit transfer);
    frame='0;frame.timestamp_ticks=logical_tick;frame.edge_index=edge_number;frame.record_seq=edge_number;
    frame.reset_n=1;frame.bytes_complete=1;frame.events_complete=1;
    frame.event_inc=transfer;frame.byte_inc=transfer ? 8 : 0;
    frame_toggle<=!frame_toggle;
  endtask
  initial begin
    void'($value$plusargs("MODE=%d",mode));
    handle=register_point("episode.pending.source","tb_episode_pending",BW_NS,4,1,"clock");
    wait(monitor_ready);
    #1000000;deliver(1000000,1,1);#1000000;deliver(2000000,2,0);
    #1000000;watermark=3000000;
    if (mode!=0) begin
      #500000;
      if (mode==2) begin $display("TB_PASS episode_pending_final");$finish;end
      reset_n=0;#1;
      if (final_seq!=1 || result.status!=BW_EPISODE_RESET_INTERRUPTED || result.bytes_complete ||
          result.events_complete || result.last_known || result.e2e_valid || epoch!=1)
        $fatal(1,"reset with a prior pending source frame must report known partial evidence");
      #(4000000-$time);deliver(3000000,3,1);#1;watermark=BW_U64_MAX;
      if (accepted!=3 || active || final_seq!=1)
        $fatal(1,"reset still accepts late raw input without restarting its statistics");
    end else begin
      #1000000;
      if (!active || final_seq!=0 || window_end>3000000)
        $fatal(1,"pending T=3 input blocks the apparently due T=4 quiet completion and window");
      deliver(3000000,3,1);#1;watermark=4000000;
      if (!active || final_seq!=0 || accepted!=3)
        $fatal(1,"a legal delayed transfer at T=3 must extend the old episode");
      #249999;deliver(4000000,4,0);#1;watermark=BW_U64_MAX;
      #(6000001-$time);
      if (active || final_seq!=1 || result.first_ticks!=1000000 || result.last_ticks!=3000000 ||
          result.tail_ticks!=4000000 || result.confirmation_ticks!=6000000 ||
          result.byte_count!=16 || result.event_count!=2 || result.duration_ticks!=3000000 ||
          !result.e2e_valid || $abs(result.e2e_gbps-5.333333333333333)>1e-10)
        $fatal(1,"raw progress preserves exact logical episode boundaries despite physical delivery delay");
    end
    $display("TB_PASS episode_pending");$finish;
  end
endmodule
