module tb_report_records;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(3)) setup();
  bw_point_mon #(.POINT_ID("records.fail"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) failed
    (.clk(1'b0),.reset_n(1'b1));
  bw_point_mon #(.POINT_ID("records.zero"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) zero
    (.clk(1'b0),.reset_n(1'b1));
  bw_point_mon #(.POINT_ID("records.missing"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) missing
    (.clk(1'b0),.reset_n(1'b1));
  initial begin
    bw_episode_result_t result;
    bw_report_summary_t summary;
    bit later_pass,invalid_actual,spoof_reset,unknown_status;
    later_pass=$test$plusargs("LATER_PASS");
    invalid_actual=$test$plusargs("INVALID_ACTUAL");spoof_reset=$test$plusargs("SPOOF_RESET");
    unknown_status=$test$plusargs("UNKNOWN_STATUS");
    wait(monitor_ready);#4000000;
    result='{scope_kind:BW_POINT,status:BW_EPISODE_COMPLETE,reason:BW_EPISODE_REASON_NONE,
      e2e_gbps:128.0,default:0};
    result.stats_epoch=7;result.result_seq=1;result.episode_id=9;
    result.first_ticks=1000000;result.last_ticks=1000000;result.tail_ticks=2000000;
    result.confirmation_ticks=3000000;result.duration_ticks=1000000;
    result.byte_count=128;result.event_count=1;result.end_total_bytes=128;result.end_total_events=1;
    result.first_known=1;result.last_known=1;result.tail_known=1;
    result.bytes_complete=1;result.events_complete=1;result.duration_valid=1;result.e2e_valid=1;
    if(invalid_actual) result.e2e_gbps=$bitstoreal(64'h7ff8000000000001);
    if(spoof_reset) result.status=BW_EPISODE_RESET_INTERRUPTED;
    if(unknown_status) result.status=bw_episode_status_t'(3'bxxx);
    emit_episode_result("records.fail",result);
    emit_episode_result("records.fail",result);
    emit_episode_result("records.fail",result);
    if(later_pass) begin
      result.stats_epoch=8;result.result_seq=2;result.episode_id=10;
      result.byte_count=200;result.end_total_bytes=200;result.e2e_gbps=200.0;
      emit_episode_result("records.fail",result);
    end
    result.stats_epoch=1;result.result_seq=1;result.episode_id=1;
    result.status=BW_EPISODE_COMPLETE;
    result.byte_count=0;result.end_total_bytes=0;result.e2e_gbps=0.0;
    emit_episode_result("records.zero",result);
    report_scope_done(BW_POINT,"unregistered.component");
    summary=check_report_summary();
    if(summary.pass_count!=1+int'(later_pass) || summary.fail_count!=int'(!(invalid_actual || spoof_reset || unknown_status)) ||
       summary.warning_count!=int'(invalid_actual || spoof_reset || unknown_status) || summary.scopes_done!=0 ||
       summary.scopes_expected!=3 || summary.finalized ||
       summary.status!=((invalid_actual || spoof_reset || unknown_status) ? BW_REPORT_WARNING : BW_REPORT_FAIL))
      $fatal(1,"immutable final replays must not recount; later PASS must retain earlier FAIL");
    $display("TB_PASS report_records continued_after_fail=1");$finish;
  end
endmodule
