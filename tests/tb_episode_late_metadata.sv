module tb_episode_late_metadata;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_record_t frame='0;
  bit frame_toggle=0, timer_preceded_metadata=0;
  int mode=1, handle;
  bw_u64_t accepted,window_seq,final_seq,tail_ticks;
  bit active,tail_known;
  bw_episode_result_t result;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  // The agreed normalized record/time seam lets the fixture explicitly choose
  // whether T's actual frame arrives before or after T's timer publication.
  bw_stats_core #(.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1)) core
    (.scope_id("episode.late_metadata"),.record(frame),.record_toggle(frame_toggle),
     .accepted_record_seq(accepted),.result_seq(window_seq),.episode_result_seq(final_seq),
     .episode_active(active),.episode_tail_ticks(tail_ticks),.episode_tail_known(tail_known),
     .episode_result(result),
     .scope_kind(BW_POINT),.stats_reset_n(1'b1),.progress_watermark_ticks(BW_U64_MAX),
     .member_control('0),.member_control_toggle(1'b0),.accepted_control_count(),
     .stats_epoch(),.total_bytes(),.total_events(),
     .window_start_ticks(),.window_end_ticks(),.window_start_cycle(),
     .window_end_cycle(),.coverage_ticks(),.coverage_cycles(),
     .window_bytes(),.window_events(),.bandwidth_gbps(),
     .bytes_per_cycle(),.window_warmup(),.window_full(),
     .bytes_complete(),.events_complete(),.denominator_valid(),
     .window_valid(),.member_reset_coverage(),.episode_status(),
     .episode_id(),.episode_first_ticks(),.episode_last_ticks(),
     .episode_confirmation_ticks(),.episode_first_cycle(),.episode_last_cycle(),
     .episode_tail_cycle(),.episode_bytes(),.episode_events(),
     .episode_duration_ticks(),.episode_first_known(),.episode_last_known(),
     .episode_bytes_complete(),.episode_events_complete(),.episode_member_reset_coverage(),
     .episode_duration_valid(),.episode_e2e_valid(),.episode_e2e_gbps(),
     .phase_current(),.phase_candidate(),.phase_active(),
     .phase_eligible(),.phase_evidence_continuous(),.phase_evidence_sufficient(),
     .phase_fit_valid(),.phase_id(),.phase_result_seq(),
     .phase_window_seq(),.phase_evidence_count(),.phase_evidence_span(),
     .phase_candidate_count(),.phase_candidate_ticks(),.phase_candidate_total_bytes(),
     .phase_candidate_total_events(),.phase_start_ticks(),.phase_confirmation_ticks(),
     .phase_fit_mean(),.phase_fit_delta(),.phase_fit_rms(),
     .phase_result());
  task automatic deliver_idle_tail();
    frame.timestamp_ticks=2000000;frame.edge_index=2;frame.record_seq=2;
    frame.event_inc=0;frame_toggle<=!frame_toggle;
  endtask
  always @(window_seq) begin
    if (mode==1 && $time==2000000 && window_seq==2) begin
      if (accepted!=1) $fatal(1,"timer-first fixture must still be awaiting the second edge metadata");
      timer_preceded_metadata=1;deliver_idle_tail();
    end
  end
  initial begin
    void'($value$plusargs("MODE=%d",mode));
    handle=register_point("episode.late_metadata","tb_episode_late_metadata",BW_NS,2,1);
    wait(monitor_ready);
    #1000000;
    frame.timestamp_ticks=1000000;frame.edge_index=1;frame.record_seq=1;
    frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    frame_toggle<=!frame_toggle;
    #1000000;if(mode==0)deliver_idle_tail();
    #1;
    if (!tail_known || tail_ticks!=2000000 || final_seq!=0 || accepted!=2)
      $fatal(1,"the later same-T frame must still establish the real tail after timer publication");
    #1000000;
    if (active || final_seq!=1 || !result.e2e_valid || result.byte_count!=0 ||
        result.event_count!=1 || result.duration_ticks!=1000000 || result.e2e_gbps!=0.0 ||
        result.confirmation_ticks!=3000000 || window_seq!=3)
      $fatal(1,"zero-byte activity completes once after tail metadata, without an extra window");
    if(mode==1 && !timer_preceded_metadata)$fatal(1,"timer-first scenario was not exercised");
    if(timer_preceded_metadata)$display("EPISODE_TIMER_FIRST_METADATA");
    $display("TB_PASS episode_late_metadata");$finish;
  end
endmodule
