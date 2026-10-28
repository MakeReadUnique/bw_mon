// Approved immutable-record seam supplements (never substitutes for) the real
// recognizer tests. All original windows are provided; neither B nor a checker
// exemption is supplied. Terminal crop is applied only after final phase input.
module tb_checker_ownership_records;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("ownership.records"),.WINDOW_WIDTH(10),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b0));
  initial begin
    bw_check_window_t row;
    bw_phase_result_t phase;
    bw_episode_result_t episode;
    bw_report_summary_t result;
    string mode;
    wait(monitor_ready);#400000000;
    if(!$value$plusargs("CASE=%s",mode))mode="normal";
    for(int n=1;n<=32;n++)begin
      row='{scope_kind:BW_POINT,stats_epoch:0,episode_id:1,seq:bw_u64_t'(n),
        ticks:measurement_start_ticks+n*10000000,left_ticks:measurement_start_ticks+(n-1)*10000000,
        u:measurement_start_ticks+n*10000000,left_u:measurement_start_ticks+(n-1)*10000000,
        value:n<=16 ? 100.0 : 200.0,valid:1,full:1,bytes_complete:1,denominator_valid:1,default:0};
      if(mode=="gap" && n==16)row.valid=0;
      if(mode=="old_fail" && n inside {13,14})row.value=106;
      if(mode=="bad_support" && n==17)row.value=198;
      if(mode=="overlap" && n==17)row.value=100;
      if(mode=="reverse" && n==15)row.value=120;
      if(mode=="reverse" && n==16)row.value=110;
      if(mode=="long_bridge" && n>=14 && n<=16)row.value=100.0+20.0*(n-13);
      if(mode=="reset_bridge" && n>=16)begin
        row.reset_coverage=1;row.reset_generation=1;
        row.last_reset_event_ticks=measurement_start_ticks+155000000;
      end
      report_sink.submit_window("ownership.records",row);
    end
    phase='{scope_kind:BW_POINT,stats_epoch:0,episode_id:1,phase_id:1,result_seq:1,
      phase_kind:BW_PHASE_STEADY,start_ticks:measurement_start_ticks+60000000,
      end_ticks:measurement_start_ticks+170000000,confirmation_ticks:measurement_start_ticks+70000000,
      support_first_seq:1,support_last_seq:7,support_count:7,support_min_gbps:100.0,support_max_gbps:100.0,
      start_known:1,end_known:1,bytes_complete:1,default:0};
    emit_phase_result("ownership.records",phase);
    phase.phase_id=2;phase.result_seq=2;phase.start_ticks=measurement_start_ticks+220000000;
    phase.end_ticks=measurement_start_ticks+321000000;phase.confirmation_ticks=measurement_start_ticks+230000000;
    phase.support_first_seq=17;phase.support_last_seq=23;phase.support_min_gbps=200;phase.support_max_gbps=200;
    if(mode=="overlap")phase.support_min_gbps=100;
    emit_phase_result("ownership.records",phase);
    episode='{scope_kind:BW_POINT,stats_epoch:0,episode_id:1,result_seq:1,status:BW_EPISODE_COMPLETE,
      first_ticks:measurement_start_ticks,tail_ticks:measurement_start_ticks+(mode=="crop" ? 225000000 : 321000000),
      first_known:1,last_known:1,tail_known:1,bytes_complete:1,default:0};
    emit_episode_result("ownership.records",episode);
    result=check_report_summary();
    if(mode=="normal")begin
      if(result.pass_count!=2 || result.fail_count!=0 || result.warning_count!=0)$fatal(1,"normal independent step");
    end else if(mode=="crop")begin
      if(result.pass_count!=0 || result.fail_count!=1 || result.warning_count!=1)$fatal(1,"cropped handoff and proof must be withdrawn");
    end else if(result.pass_count!=1 || result.fail_count!=1 || result.warning_count!=0)
      $fatal(1,"old anomaly or rejected step cannot become PASS");
    $display("TB_PASS checker_ownership_records");$finish;
  end
endmodule
