module tb_episode_controls;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,valid=0,scope_reset_n=1;
  logic [63:0] size_bytes=0;
  bw_u64_t result_seq,epoch,total_bytes;
  bit active;
  bw_episode_result_t result;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("episode.controls"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4)) point
    (.clk(clk),.reset_n(reset_n),.valid(valid),.size_bytes(size_bytes),.size_known(1'b1));
  // Agreed normalized scope/control seam: an actual group collector is not
  // required to establish the shared core's independent episode contract.
  bw_stats_core #(.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4)) ancestor
    (.scope_id("episode.ancestor"),.scope_kind(BW_GROUP),.record(point.raw_record),
     .record_toggle(point.record_toggle),.member_control(point.raw_control),
     .member_control_toggle(point.control_toggle),.stats_reset_n(scope_reset_n),
     .episode_active(active),.episode_result_seq(result_seq),.episode_result(result),
     .stats_epoch(epoch),.total_bytes(total_bytes),
     .progress_watermark_ticks(BW_U64_MAX),.accepted_record_seq(),.accepted_control_count(),
     .result_seq(),.total_events(),.window_start_ticks(),
     .window_end_ticks(),.window_start_cycle(),.window_end_cycle(),
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
  task automatic sample_at(bw_u64_t ticks,bit transfer,bw_u64_t bytes);
    #(ticks-$time);valid=transfer;size_bytes=bytes;clk=1;#1;clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    sample_at(1000000,1,8);sample_at(2000000,0,0);
    #(4500000-$time);reset_n=1'bx;
    #(6250000-$time);
    if (!point.episode_active || !active || point.episode_result_seq!=0 || result_seq!=0)
      $fatal(1,"no-edge unknown reset must interrupt quiet before the original 6ns deadline");
    #(6500000-$time);reset_n=1;
    #(9000001-$time);
    if (!point.bytes_complete || !point.episode_active || point.episode_bytes_complete ||
        point.episode_last_known)
      $fatal(1,"window recovery cannot repair an episode after a no-edge unknown observation");
    #(10500001-$time);
    if (point.episode_active || active || point.episode_result_seq!=1 || result_seq!=1 ||
        point.episode_result.confirmation_ticks!=10500000 || result.confirmation_ticks!=10500000 ||
        point.episode_result.last_known || result.last_known || result.bytes_complete ||
        result.e2e_valid || result.scope_kind!=BW_GROUP || epoch!=0 || total_bytes!=8)
      $fatal(1,"quiet resumes at the actual control recovery time and preserves independent sticky quality");
    sample_at(12000000,1,0);sample_at(13000000,0,0);
    #(14500000-$time);reset_n=0;
    #1;
    if (point.episode_result_seq!=2 || point.episode_result.status!=BW_EPISODE_RESET_INTERRUPTED ||
        point.episode_result.stats_epoch!=0 || point.stats_epoch!=1 || point.episode_active ||
        !active || epoch!=0 || result_seq!=1)
      $fatal(1,"own reset interrupts only the point episode, while member reset leaves the ancestor alive");
    #(17000001-$time);
    if (active || result_seq!=2 || !result.e2e_valid || result.e2e_gbps!=0.0 ||
        result.byte_count!=0 || result.event_count!=1 || result.member_reset_coverage ||
        result.first_ticks!=12000000 || result.tail_ticks!=13000000)
      $fatal(1,"a complete zero-byte ancestor episode excludes reset coverage after its tail");
    #(18000000-$time);reset_n=1;
    sample_at(19000000,1,8);
    #(19500000-$time);reset_n=0;
    sample_at(20000000,0,0);
    if (!ancestor.episode_tail_known || !ancestor.episode_member_reset_coverage)
      $fatal(1,"known member-reset coverage must be visible as soon as the actual tail establishes its overlap");
    #(20500000-$time);reset_n=1;
    #(24000001-$time);
    if (active || result_seq!=3 || !result.e2e_valid || result.e2e_gbps!=8.0 ||
        !result.member_reset_coverage || result.first_ticks!=19000000 || result.tail_ticks!=20000000 ||
        total_bytes!=16 || epoch!=0 || point.episode_result_seq!=3)
      $fatal(1,"an actual member reset intersecting the transfer cycle is coverage, not lost known bytes");
    #(25000000-$time);scope_reset_n=0;
    #(25500000-$time);reset_n=1'bx;
    #(26000000-$time);reset_n=1;
    #(27000000-$time);scope_reset_n=1;
    sample_at(28000000,1,8);sample_at(29000000,0,0);
    #(33000001-$time);
    if (active || result_seq!=4 || !result.e2e_valid || !result.first_known ||
        !result.bytes_complete || result.first_ticks!=28000000 || result.tail_ticks!=29000000 ||
        result.e2e_gbps!=8.0 || epoch!=1 || total_bytes!=8)
      $fatal(1,"unknown member controls wholly inside own reset cannot poison the new analysis epoch");
    $display("TB_PASS episode_controls");$finish;
  end
endmodule
