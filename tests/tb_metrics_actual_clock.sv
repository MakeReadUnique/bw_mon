module tb_metrics_actual_clock;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic [1:0] clk=0,valid=0;
  logic [63:0] bytes[2];
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("metrics.clock%0d",g)),.WINDOW_BASIS(BW_CYCLE),
      .WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(1),
      .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
      .PHASE_STEADY_ENTER_ABS(0.1),.PHASE_STEADY_ENTER_REL(0.0),
      .PHASE_STEADY_EXIT_ABS(0.2),.PHASE_STEADY_EXIT_REL(0.0),
      .PHASE_RMS_ENTER_ABS(0.01),.PHASE_RMS_ENTER_REL(0.0),
      .PHASE_RMS_EXIT_ABS(0.01),.PHASE_RMS_EXIT_REL(0.0),
      .PHASE_TREND_ABS(5.0),.PHASE_TREND_REL(0.0)) point
      (.clk(clk[g]),.reset_n(1'b1),.valid(valid[g]),.size_bytes(bytes[g]),.size_known(1'b1));
  end
  task automatic edge_at(int g,bw_u64_t tick,bit transfer,bw_u64_t count);
    #(tick-$time);valid[g]=transfer;bytes[g]=count;clk[g]=1;#1;clk[g]=0;
  endtask
  initial begin
    wait(monitor_ready);
    fork
      begin
        edge_at(0,10000000,1,10);edge_at(0,11000000,1,12);edge_at(0,12000000,1,32);
        edge_at(0,14000000,1,8);edge_at(0,20000000,0,0);edge_at(0,21000000,0,0);
      end
      begin
        edge_at(1,10000000,1,5);edge_at(1,10500000,1,6);edge_at(1,11000000,1,16);
        edge_at(1,12000000,1,8);edge_at(1,15000000,0,0);edge_at(1,16000000,0,0);
      end
    join
    if(scopes[0].point.episode_result.variation.sample_count!=3 ||
       scopes[1].point.episode_result.variation.sample_count!=3 ||
       $abs(scopes[0].point.episode_result.variation.mean_gbps-12.666666666666666)>1e-10 ||
       $abs(scopes[1].point.episode_result.variation.mean_gbps-12.666666666666666)>1e-10 ||
       $abs(scopes[0].point.episode_result.variation.stddev_gbps-2.494438257849294)>1e-10 ||
       $abs(scopes[1].point.episode_result.variation.cv_pct-19.69293361459969)>1e-10 ||
       scopes[0].point.episode_result.variation.sample_span_ticks!=3000000 ||
       scopes[1].point.episode_result.variation.sample_span_ticks!=1500000 ||
       scopes[0].point.phase_result.duration_ticks!=6000000 ||
       scopes[1].point.phase_result.duration_ticks!=3000000 ||
       $abs(scopes[0].point.phase_result.bandwidth_gbps-1.3333333333333333)>1e-10 ||
       $abs(scopes[1].point.phase_result.bandwidth_gbps-2.6666666666666665)>1e-10 ||
       scopes[0].point.phase_result.variation.sample_count!=1 ||
       scopes[0].point.phase_result.variation.mean_gbps!=16.0)
      $fatal(1,"cycle variation equally weights10/12/16 despite unequal physical intervals and2GHz edges; raw stage duration stays physical");
    $display("TB_PASS metrics_actual_clock");$finish;
  end
endmodule
