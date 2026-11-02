module tb_metrics_late_recovery;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_record_t frame='0;
  bit frame_toggle=0;
  logic reset_n=1;
  bw_control_t control='0;
  bit control_toggle=0;
  bw_u64_t watermark=BW_U64_MAX,accepted,final_seq,window_end,epoch;
  bit active;
  int mode=0,handle;
  bw_episode_result_t result;
  bw_mon_setup setup();
  bw_stats_core #(.WINDOW_WIDTH(4),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4)) core
    (.scope_id("metrics.late_recovery"),.scope_kind(BW_GROUP),.record(frame),.record_toggle(frame_toggle),
     .stats_reset_n(reset_n),.progress_watermark_ticks(watermark),.accepted_record_seq(accepted),
     .episode_active(active),.episode_result_seq(final_seq),.episode_result(result),
     .window_end_ticks(window_end),.stats_epoch(epoch),
     .member_control(control),.member_control_toggle(control_toggle),.accepted_control_count(),
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
     .episode_e2e_gbps(),
     .phase_current(),.phase_candidate(),.phase_active(),
     .phase_eligible(),.phase_evidence_continuous(),.phase_evidence_sufficient(),
     .phase_fit_valid(),.phase_id(),.phase_result_seq(),
     .phase_window_seq(),.phase_evidence_count(),.phase_evidence_span(),
     .phase_candidate_count(),.phase_candidate_ticks(),.phase_candidate_total_bytes(),
     .phase_candidate_total_events(),.phase_start_ticks(),.phase_confirmation_ticks(),
     .phase_fit_mean(),.phase_fit_delta(),.phase_fit_rms(),
     .phase_result());
  task automatic deliver(bw_u64_t logical_tick,bw_u64_t edge_number,bit transfer);
    frame='0;frame.timestamp_ticks=measurement_start_ticks+logical_tick;frame.edge_index=edge_number;frame.record_seq=edge_number;
    frame.reset_n=1;frame.bytes_complete=1;frame.events_complete=1;
    frame.event_inc=transfer;frame.byte_inc=transfer ? 8 : 0;
    frame_toggle<=!frame_toggle;
  endtask
  task automatic deliver_control(bw_u64_t logical_tick,bw_u64_t sequence_id,logic reset_level);
    control='0;control.timestamp_ticks=measurement_start_ticks+logical_tick;control.control_seq=sequence_id;
    control.point_handle=0;control.reset_n=reset_level;control_toggle<=!control_toggle;
  endtask
  initial begin
    void'($value$plusargs("MODE=%d",mode));
    handle=register_point("metrics.late.source","tb_metrics_late_recovery",BW_NS,4,1);
    wait(monitor_ready);
    #1000000;deliver(1000000,1,1);#1000000;deliver(2000000,2,0);
    #500000;deliver_control(2500000,1,1'bx);watermark=measurement_start_ticks+3500000;
    if(mode!=0)begin
      #(measurement_start_ticks+9000000-$time);reset_n=0;
      #(measurement_start_ticks+9500000-$time);reset_n=1;
      if(mode==3)begin
        #(measurement_start_ticks+9600000-$time);reset_n=1'bx;
        #(measurement_start_ticks+9700000-$time);reset_n=1;
      end
    end
    #(measurement_start_ticks+10000000-$time);
    // Original recovery3.5 reaches the owner together with its later raw frame.
    // Both channels are the agreed normalized record/control component seam.
    deliver_control(mode==2 ? 9750000 : mode==4 ? 9500000 : 3500000,2,1'b1);deliver(10000000,3,1);watermark=measurement_start_ticks+10000000;
    #1;
    if(final_seq!=1 || result.status!=(mode!=0 ? BW_EPISODE_RESET_INTERRUPTED : BW_EPISODE_COMPLETE) ||
       result.confirmation_ticks!=measurement_start_ticks+(mode!=0 ? 9000000 : 7500000) ||
       result.last_known || result.e2e_valid || result.variation.minmax_valid ||
       result.variation.minmax_reason!=(mode!=0 ? BW_METRIC_RESET : BW_METRIC_BOUNDARY_UNKNOWN) ||
       !active || accepted!=3 || epoch!=int'(mode!=0))
      $fatal(1,"late original recovery must preserve Q7.5 completion and start new episode10 without backward quality queries");
    #(measurement_start_ticks+11000000-$time);deliver(11000000,4,0);watermark=BW_U64_MAX;
    #(measurement_start_ticks+15000002-$time);
    if(final_seq!=2 || result.e2e_valid!=(!(mode inside {2,3})) || result.first_known!=(!(mode inside {2,3})) ||
       result.first_ticks!=measurement_start_ticks+10000000 || result.tail_ticks!=measurement_start_ticks+11000000 || result.confirmation_ticks!=measurement_start_ticks+15000000 ||
       (!(mode inside {2,3}) && result.e2e_gbps!=8.0))
      $fatal(1,"new episode quality must retain actual epoch gaps and exclude historical uncertainty");
    $display("TB_PASS metrics_late_recovery");$finish;
  end
endmodule
