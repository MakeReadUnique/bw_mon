// Compare the same raw numeric input under affine compression and deliberate
// quality-run splitting in one execution, without exposing container contents.
module tb_checker_equivalence;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:points
    bw_point_mon #(.POINT_ID(g==0 ? "numeric.compressed" : "numeric.expanded"),.WINDOW_WIDTH(10),.EPISODE_ENABLE(1)) point
      (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  end
  initial begin
    string mode,id;
    real value;
    bit outside;
    bw_check_window_t row;
    bw_phase_result_t platform;
    bw_episode_result_t episode;
    bw_report_summary_t result;
    wait(monitor_ready);#200000000;
    if(!$value$plusargs("CASE=%s",mode))mode="low_equal";
    outside=mode inside {"high_over","low_over"};
    case(mode)
      "high_equal":value=105.0;
      "high_over":value=105.1;
      "low_over":value=94.9;
      default:value=95.0;
    endcase
    for(int g=0;g<2;g++)begin
      id=g==0 ? "numeric.compressed" : "numeric.expanded";
      for(int n=1;n<=9;n++)begin
        row='{scope_kind:BW_POINT,stats_epoch:0,episode_id:1,seq:bw_u64_t'(n),
          left_ticks:measurement_start_ticks+(n-1)*10000000,ticks:measurement_start_ticks+n*10000000,
          left_u:measurement_start_ticks+(n-1)*10000000,u:measurement_start_ticks+n*10000000,
          value:(n==7 || n==8) ? value : 100.0,valid:1,full:1,bytes_complete:1,denominator_valid:1,
          reset_coverage:g==1 ? n%2 : 0,default:0};
        report_sink.submit_window(id,row);
      end
      platform='{scope_kind:BW_POINT,episode_id:1,phase_id:1,result_seq:1,phase_kind:BW_PHASE_STEADY,
        start_ticks:measurement_start_ticks,end_ticks:measurement_start_ticks+100000000,
        start_known:1,end_known:1,default:0};
      emit_phase_result(id,platform);
      episode='{scope_kind:BW_POINT,episode_id:1,result_seq:1,status:BW_EPISODE_COMPLETE,
        first_ticks:measurement_start_ticks,tail_ticks:measurement_start_ticks+100000000,
        first_known:1,last_known:1,tail_known:1,bytes_complete:1,default:0};
      emit_episode_result(id,episode);
    end
    result=check_report_summary();
    if(result.warning_count!=0 || result.pass_count!=(outside ? 0 : 2) || result.fail_count!=(outside ? 2 : 0))
      $fatal(1,"compressed and split evidence must preserve strict threshold outcomes");
    $display("TB_PASS checker_equivalence case=%s",mode);$finish;
  end
endmodule
