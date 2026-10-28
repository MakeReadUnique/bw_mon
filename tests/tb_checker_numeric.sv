// Approved final-record/numerical seam. Six immutable raw rows establish B;
// fixtures never supply a baseline or change the fixed percentage/duration.
module tb_checker_numeric;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("numeric.check"),.WINDOW_WIDTH(10),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b0));
  initial begin
    bw_check_window_t row;
    bw_phase_result_t platform;
    bw_episode_result_t episode;
    bw_report_summary_t result;
    string mode;
    int count,expected;
    bit dense,cycle_basis;
    bw_u64_t stride,endpoint;
    real baseline;
    wait(monitor_ready);#200000000;
    // Deliver every logical 10..101ns publication together at 200ns. Arrival
    // spacing supplies no sustained duration; only original endpoints do.
    if(!$value$plusargs("CASE=%s",mode))mode="low_equal";
    dense=mode inside {"dense_short","dense_fail","coverage"};
    cycle_basis=mode=="cycle";
    stride=dense ? 1 : 10;
    count=(mode inside {"dense_short","dense_fail"}) ? 18 : (mode=="reference_short" ? 5 : 9);
    baseline=mode=="zero" ? 0.0 : ((mode inside {"nearzero","nearzero_pass"}) ? 1e-200 : 100.0);
    // 0 PASS, 1 FAIL, 2 WARNING: worked examples independent of report fields.
    expected=(mode inside {"high_over","low_over","expanded_high_over","expanded_low_over","explicit_time","alternating","reference_backcheck","nearzero","reset_fail","cycle","dense_fail"}) ? 1 :
      ((mode inside {"gap","zero","reference_short","coverage","truncated","terminal_crop","start_unknown","unknown_status"}) ? 2 : 0);
    report_sink.analysis_scope(BW_POINT,"numeric.check",1,cycle_basis ? BW_CYCLE : BW_NS,10,stride);
    for(int n=1;n<=count;n++)begin
      endpoint=dense ? 9+n : 10*n;
      if(mode=="explicit_time")endpoint+=10;
      row='{scope_kind:BW_POINT,stats_epoch:0,episode_id:1,seq:bw_u64_t'(n),
        left_ticks:measurement_start_ticks+(endpoint-10)*(cycle_basis ? 1000 : 1000000),
        ticks:measurement_start_ticks+endpoint*(cycle_basis ? 1000 : 1000000),
        left_u:cycle_basis ? endpoint-10 : measurement_start_ticks+(endpoint-10)*1000000,
        u:cycle_basis ? endpoint : measurement_start_ticks+endpoint*1000000,
        value:baseline,valid:1,full:1,bytes_complete:1,denominator_valid:1,default:0};
      if(n==7 || n==8)begin
        case(mode)
          "low_equal","expanded","platform_replay":row.value=95.0;
          "expanded_high_equal":row.value=105.0;
          "expanded_high_over":row.value=105.1;
          "expanded_low_over":row.value=94.9;
          "high_equal":row.value=105.0;
          "high_inside":row.value=104.9;
          "low_inside":row.value=95.1;
          "high_over","reset_fail","cycle","explicit_time":row.value=105.1;
          "low_over":row.value=94.9;
          "alternating":row.value=n==7 ? 106.0 : 94.0;
          "nearzero":row.value=1.08e-200;
          "single_peak":row.value=n==7 ? 106.0 : 100.0;
          "gap":begin row.value=106.0;if(n==8)row.valid=0;end
        endcase
      end
      if(mode=="gap" && n==9)row.value=106.0;
      if(mode=="reference_backcheck")row.value=(n%2) ? 92.0 : 108.0;
      if(mode=="dense_short" && n>=7 && n<=9)row.value=106.0;
      if(mode=="dense_fail" && n>=7 && n<=17)row.value=106.0;
      // Known member reset coverage changes compression grouping but does not
      // invalidate known bytes or change the numerical rule's evidence.
      if(mode inside {"expanded","expanded_high_equal","expanded_high_over","expanded_low_over"})row.reset_coverage=n%2;
      report_sink.submit_window("numeric.check",row);
      report_sink.submit_window("numeric.check",row); // stale snapshot adds nothing
    end
    platform='{default:0};platform.scope_kind=BW_POINT;platform.episode_id=1;platform.phase_id=1;
    platform.result_seq=1;platform.phase_kind=BW_PHASE_STEADY;
    platform.start_ticks=measurement_start_ticks;
    platform.end_ticks=row.ticks+1000000;
    platform.start_known=mode!="start_unknown";platform.end_known=1;platform.bytes_complete=1;
    if(mode=="explicit_time")begin
      platform.phase_kind=BW_PHASE_RAMP;platform.end_ticks=measurement_start_ticks+10000000;
      platform.duration_ticks=10000000;platform.duration_valid=1;platform.duration_reason=BW_METRIC_OK;
      emit_phase_result("numeric.check",platform);
      platform.phase_id=2;platform.result_seq=2;platform.phase_kind=BW_PHASE_STEADY;
      platform.start_ticks=measurement_start_ticks+10000000;platform.end_ticks=row.ticks+1000000;
    end
    emit_phase_result("numeric.check",platform);emit_phase_result("numeric.check",platform);
    if(mode=="platform_replay")begin platform.result_seq=2;emit_phase_result("numeric.check",platform);end
    episode='{default:0};episode.scope_kind=BW_POINT;episode.episode_id=1;episode.result_seq=1;
    episode.status=mode=="reset_fail" ? BW_EPISODE_RESET_INTERRUPTED :
      (mode=="truncated" ? BW_EPISODE_TRUNCATED : BW_EPISODE_COMPLETE);
    if(mode=="unknown_status")episode.status=bw_episode_status_t'(3'bxxx);
    episode.first_known=1;episode.last_known=1;episode.tail_known=1;
    episode.bytes_complete=1;episode.first_ticks=measurement_start_ticks;episode.tail_ticks=platform.end_ticks;
    if(mode=="terminal_crop")episode.tail_ticks=measurement_start_ticks+55000000;
    emit_episode_result("numeric.check",episode);emit_episode_result("numeric.check",episode);
    result=check_report_summary();
    if(result.pass_count!=((expected==0 ? 1 : 0)+(mode=="explicit_time" ? 1 : 0)) || result.fail_count!=(expected==1 ? 1 : 0) ||
       result.warning_count!=(expected==2 ? 1 : 0))
      $fatal(1,"fixed variation numerical case %s expected outcome %0d",mode,expected);
    $display("TB_PASS checker_numeric case=%s",mode);$finish;
  end
endmodule
