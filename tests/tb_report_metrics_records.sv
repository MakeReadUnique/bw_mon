module tb_report_metrics_records;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("report.metrics"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) point
    (.clk(1'b0),.reset_n(1'b1));
  initial begin
    bw_phase_result_t fragment;
    bw_episode_result_t episode;
    bw_variation_result_t variation;
    bw_report_summary_t checked;
    int expected_pass,expected_fail,expected_warning;
    bit bad_duration,later_truncated,raw_incomplete,selection_incomplete,nonfinite_variation,zero_mean;
    expected_pass=13;expected_fail=0;expected_warning=0;
    bad_duration=$test$plusargs("BAD_DURATION");later_truncated=$test$plusargs("LATER_TRUNCATED");
    raw_incomplete=$test$plusargs("RAW_INCOMPLETE");selection_incomplete=$test$plusargs("SELECTION_INCOMPLETE");
    nonfinite_variation=$test$plusargs("NONFINITE_VARIATION");zero_mean=$test$plusargs("ZERO_MEAN");
    if($value$plusargs("EXPECT_PASS=%d",expected_pass))begin end
    if($value$plusargs("EXPECT_FAIL=%d",expected_fail))begin end
    if($value$plusargs("EXPECT_WARNING=%d",expected_warning))begin end
    wait(monitor_ready);#20000000;
    variation='{window_basis:BW_NS,window_width:1,update_stride:1,sample_count:6,
      first_sample_ticks:14000000,last_sample_ticks:19000000,sample_span_ticks:5000000,
      interval_known:1,coverage_complete:1,minmax_valid:1,stddev_valid:1,cv_valid:1,
      minmax_reason:BW_METRIC_OK,stddev_reason:BW_METRIC_OK,cv_reason:BW_METRIC_OK,
      mean_gbps:20.0,min_gbps:20.0,max_gbps:20.0,stddev_gbps:0.0,cv_pct:0.0,default:0};
    fragment='{scope_kind:BW_POINT,stats_epoch:2,episode_id:3,phase_id:1,result_seq:1,
      phase_kind:BW_PHASE_RAMP,end_reason:BW_PHASE_CHANGE,episode_status:BW_EPISODE_ACTIVE,
      start_ticks:1000000,end_ticks:4000000,confirmation_ticks:2000000,
      start_known:1,end_known:1,duration_valid:1,duration_ticks:3000000,
      bytes_complete:1,events_complete:1,bandwidth_valid:1,duration_reason:BW_METRIC_OK,
      bandwidth_reason:BW_METRIC_OK,variation:variation,default:0};
    if($test$plusargs("RESULT_BUDGET"))begin
      #(40001000002-$time);emit_phase_result("report.metrics",fragment);
      $fatal(1,"expected core error did not occur");
    end
    if($test$plusargs("TRANSIENT_DEFERRED"))set_deferred_core_failure(0,1);
    if($test$plusargs("INITIAL_SNAPSHOT"))begin
      fragment.result_seq=0;emit_phase_result("report.metrics",fragment);fragment.result_seq=1;
    end
    if($test$plusargs("UNKNOWN_PHASE_KIND"))fragment.phase_kind=bw_phase_t'(3'bxxx);
    if(bad_duration)fragment.duration_valid=0;
    emit_phase_result("report.metrics",fragment);emit_phase_result("report.metrics",fragment);
    fragment.duration_valid=1;fragment.phase_kind=BW_PHASE_RAMP;fragment.phase_id=2;fragment.result_seq=2;
    fragment.start_ticks=5000000;fragment.end_ticks=9000000;fragment.duration_ticks=4000000;
    emit_phase_result("report.metrics",fragment);
    fragment.phase_kind=BW_PHASE_FALL;fragment.phase_id=3;fragment.result_seq=3;
    fragment.start_ticks=10000000;fragment.end_ticks=13000000;fragment.duration_ticks=3000000;
    emit_phase_result("report.metrics",fragment);emit_phase_result("report.metrics",fragment);
    fragment.phase_kind=BW_PHASE_STEADY;fragment.phase_id=4;fragment.result_seq=4;
    fragment.start_ticks=14000000;fragment.end_ticks=20000000;fragment.duration_ticks=6000000;
    fragment.byte_count=120;fragment.event_count=6;fragment.bandwidth_gbps=20.0;
    fragment.start_total_bytes=260;fragment.end_total_bytes=380;
    emit_phase_result("report.metrics",fragment);
    episode='{scope_kind:BW_POINT,stats_epoch:2,episode_id:3,result_seq:1,
      status:BW_EPISODE_COMPLETE,reason:BW_EPISODE_REASON_NONE,
      first_ticks:1000000,last_ticks:19000000,tail_ticks:20000000,confirmation_ticks:20000000,
      byte_count:380,event_count:19,duration_ticks:19000000,first_known:1,last_known:1,tail_known:1,
      bytes_complete:1,events_complete:1,duration_valid:1,e2e_valid:1,e2e_gbps:20.0,
      end_total_bytes:380,end_total_events:19,variation:variation,
      last_steady_found:1,last_steady_selection_valid:1,last_steady_reason:BW_METRIC_OK,
      last_steady:fragment,default:0};
    // The eight selected values are10,10,20,20,20,20,20,20; constant steady suffix has6.
    episode.variation.sample_count=8;episode.variation.first_sample_ticks=12000000;
    episode.variation.sample_span_ticks=7000000;episode.variation.mean_gbps=17.5;
    episode.variation.min_gbps=10;episode.variation.max_gbps=20;
    episode.variation.stddev_gbps=4.330127018922193;episode.variation.cv_pct=24.743582965269675;
    if(raw_incomplete)begin
      episode.bytes_complete=0;episode.e2e_valid=0;
      episode.last_steady.bytes_complete=0;episode.last_steady.bandwidth_valid=0;
      episode.last_steady.bandwidth_reason=BW_METRIC_BYTES_UNKNOWN;
    end
    if(selection_incomplete)begin
      episode.last_steady_selection_valid=0;episode.last_steady_reason=BW_METRIC_OBSERVATION_UNKNOWN;
    end
    if(nonfinite_variation)episode.variation.stddev_gbps=$bitstoreal(64'h7ff8000000000001);
    if(zero_mean)episode.variation.mean_gbps=0;
    if($test$plusargs("UNKNOWN_STEADY_KIND"))episode.last_steady.phase_kind=bw_phase_t'(3'bxxx);
    if($test$plusargs("BAD_VARIATION_REASON"))episode.variation.stddev_reason=BW_METRIC_OBSERVATION_UNKNOWN;
    if($test$plusargs("INITIAL_SNAPSHOT"))begin
      episode.result_seq=0;emit_episode_result("report.metrics",episode);episode.result_seq=1;
    end
    emit_episode_result("report.metrics",episode);emit_episode_result("report.metrics",episode);
    // Stream high-water marks are separate; phase4 cannot be rechecked as an episode.
    emit_phase_result("report.metrics",fragment);
    if(later_truncated)begin
      episode.result_seq=2;episode.episode_id=4;episode.status=BW_EPISODE_TRUNCATED;
      episode.reason=BW_EPISODE_OBSERVATION_END;
      // Deliberately retain the earlier numeric plateau: representative selection is still unavailable.
      episode.last_steady_selection_valid=0;episode.last_steady_reason=BW_METRIC_TRUNCATED;
      emit_episode_result("report.metrics",episode);emit_episode_result("report.metrics",episode);
    end
    if($test$plusargs("TRANSIENT_DEFERRED"))set_deferred_core_failure(0,0);
    checked=check_report_summary();
    if(checked.pass_count!=expected_pass || checked.fail_count!=expected_fail ||
       checked.warning_count!=expected_warning || checked.finalized)
      $fatal(1,"configured metric rules settle once and independently: got%0d/%0d/%0d expected%0d/%0d/%0d",
        checked.pass_count,checked.fail_count,checked.warning_count,expected_pass,expected_fail,expected_warning);
    $display("TB_PASS report_metrics_records continued_after_metric_conclusions=1");$finish;
  end
endmodule
