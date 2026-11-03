module tb_checker_replay;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("numeric.replay"),.WINDOW_WIDTH(10),.EPISODE_ENABLE(1)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  bw_group_mon #(.GROUP_ID("numeric.replay"),.WINDOW_WIDTH(10),.EPISODE_ENABLE(1)) group_mon
    (.clk(1'b0),.reset_n(1'b1));
  initial add_point_member("numeric.replay","numeric.replay");
  initial begin
    bw_check_window_t row;
    bw_phase_result_t phases[2];
    bw_episode_result_t episodes[2];
    bw_report_summary_t result;
    bw_u64_t base,epoch,identity;
    wait(monitor_ready);
    for(int batch=0;batch<3;batch++)begin
      #200000000;
      base=measurement_start_ticks+batch*200000000;
      epoch=batch==2 ? 1 : 0;identity=batch==1 ? 2 : 1;
      for(int kind=0;kind<2;kind++)begin
        for(int n=1;n<=9;n++)begin
          row='{scope_kind:bw_scope_t'(kind),stats_epoch:epoch,episode_id:identity,
            seq:bw_u64_t'(batch*9+n),left_ticks:base+(n-1)*10000000,ticks:base+n*10000000,
            left_u:base+(n-1)*10000000,u:base+n*10000000,value:100.0,
            valid:1,full:1,bytes_complete:1,denominator_valid:1,default:0};
          report_sink.submit_window("numeric.replay",row);
        end
        phases[kind]='{scope_kind:bw_scope_t'(kind),stats_epoch:epoch,episode_id:identity,
          phase_id:identity,result_seq:bw_u64_t'(batch+1),phase_kind:BW_PHASE_STEADY,
          start_ticks:base,end_ticks:base+100000000,start_known:1,end_known:1,
          bytes_complete:1,events_complete:1,duration_valid:1,duration_ticks:100000000,
          bandwidth_valid:1,bandwidth_gbps:100.0,byte_count:10000,default:0};
        episodes[kind]='{scope_kind:bw_scope_t'(kind),stats_epoch:epoch,episode_id:identity,
          result_seq:bw_u64_t'(batch+1),status:BW_EPISODE_COMPLETE,first_ticks:base,
          last_ticks:base+90000000,tail_ticks:base+100000000,first_known:1,last_known:1,tail_known:1,
          bytes_complete:1,events_complete:1,duration_valid:1,duration_ticks:100000000,
          byte_count:10000,e2e_valid:1,e2e_gbps:100.0,default:0};
        emit_phase_result("numeric.replay",phases[kind]);
        emit_episode_result("numeric.replay",episodes[kind]);
      end
      for(int kind=0;kind<2;kind++)begin
        episodes[kind].result_seq=100+batch;
        emit_episode_result("numeric.replay",episodes[kind]);
      end
      result=check_report_summary();
      if(result.pass_count!=(batch+1)*4 || result.fail_count!=0 || result.warning_count!=0)
        $fatal(1,"new delivery numbers cannot resettle released typed episode identities");
      for(int kind=0;kind<2;kind++)begin
        phases[kind].result_seq=200+batch;episodes[kind].result_seq=200+batch;
        emit_phase_result("numeric.replay",phases[kind]);
        emit_episode_result("numeric.replay",episodes[kind]);
      end
      result=check_report_summary();
      if(result.pass_count!=(batch+1)*4 || result.fail_count!=0 || result.warning_count!=0)
        $fatal(1,"released platform replay must not create reference warnings or suppress the next real identity");
    end
    $display("TB_PASS checker_replay");$finish;
  end
endmodule
