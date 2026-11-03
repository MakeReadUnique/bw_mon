module tb_report_group_metrics #(parameter bw_mon_pkg::bw_basis_t BASIS=bw_mon_pkg::BW_NS);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0,child_reset_n=1;
  logic [2:0] point_reset_n='1;
  logic [63:0] bytes[3];
  string mode;
  bw_mon_setup setup();
  for(genvar p=0;p<3;p++)begin:points
    bw_point_mon #(.POINT_ID(p==0 ? "shared" : $sformatf("leaf%0d",p)),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) mon
      (.clk(clk),.reset_n(point_reset_n[p]),.valid(valid),.size_bytes(bytes[p]),.size_known(1'b1));
  end
  bw_group_mon #(.GROUP_ID("shared"),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2),.PHASE_ENABLE(1)) child
    (.clk(clk),.reset_n(child_reset_n));
  bw_group_mon #(.GROUP_ID("parent"),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2),.PHASE_ENABLE(1)) parent
    (.clk(clk),.reset_n(1'b1));
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="normal";
    add_point_member("shared","shared");add_point_member("shared","leaf1");
    add_group_member("parent","shared");add_point_member("parent","leaf2");
    wait(monitor_ready);
    bytes[0]=40;bytes[1]=60;bytes[2]=20;
    for(int t=1;t<=13;t++)begin
      #(measurement_start_ticks+ns_to_ticks(t)-100000-$time);
      if(t==5)begin
        if(mode=="child_reset")child_reset_n=0;
        if(mode=="point_reset")point_reset_n[0]=0;
        if(mode=="size_unknown")bytes[0]='x;
      end
      #(measurement_start_ticks+ns_to_ticks(t)-$time);valid=t<=10;clk=1;#1;clk=0;
      if(t==5)begin
        if(parent.raw_record.byte_inc!=((mode=="point_reset" || mode=="size_unknown") ? 80 : 120) ||
           parent.raw_record.event_inc!=(mode=="point_reset" ? 2 : 3) || parent.stats_epoch!=0 ||
           !parent.episode_active || parent.episode_id!=1)
          $fatal(1,"parent raw and episode supply must be independent of child statistics reset");
        #99999;child_reset_n=1;point_reset_n[0]=1;bytes[0]=40;
      end
    end
    if(parent.episode_result_seq!=1 || parent.episode_result_stats_epoch!=0 || parent.episode_result_episode_id!=1 ||
       parent.episode_result.first_ticks!=1000001 || parent.episode_result.tail_ticks!=11000001 ||
       parent.episode_result.duration_ticks!=10000000 || parent.episode_result.event_count!=(mode=="point_reset" ? 29 : 30) ||
       parent.episode_result.byte_count!=((mode=="point_reset" || mode=="size_unknown") ? 1160 : 1200) ||
       parent.episode_result.member_reset_coverage!=(mode=="point_reset") ||
       parent.episode_result.e2e_valid==(mode=="size_unknown") ||
       (mode!="size_unknown" && parent.episode_e2e_gbps!=(mode=="point_reset" ? 116.0 : 120.0)))
      $fatal(1,"typed group final raw120/116, known reset coverage and unknown bytes require independent evidence");
    if(mode=="normal" || mode=="child_reset")begin
      if(!parent.episode_last_steady_selection_valid || parent.episode_last_steady_bandwidth_gbps!=120.0 ||
         !parent.episode_variation_cv_valid || parent.episode_variation_cv_pct!=0 ||
         parent.phase_result_episode_id!=1 || parent.phase_result_stats_epoch!=0 ||
         !parent.phase_duration_valid || parent.phase_result_end_ticks!=11000001)
        $fatal(1,"group public phase/variation/immutable identity aliases must expose its independently shared core results");
    end
    if(mode=="child_reset" && (child.stats_epoch!=1 || child.episode_result_seq!=2 ||
       child.episode_result_stats_epoch!=1 || child.episode_result.first_ticks!=6000001 ||
       child.episode_result.byte_count!=500 || child.episode_e2e_gbps!=100.0 ||
       parent.stats_epoch!=0 || parent.episode_result.member_reset_coverage))
      $fatal(1,"child epoch reset must split only child episodes while parent complete1200/10 remains intact");
    if($test$plusargs("REPEAT"))begin
      for(int t=14;t<=17;t++)begin
        #(measurement_start_ticks+ns_to_ticks(t)-$time);valid=t==14;clk=1;#1;clk=0;
        if(t==14 && (parent.episode_id!=2 || !parent.episode_active ||
           parent.episode_result_episode_id!=1 || parent.episode_result_first_ticks!=1000001 ||
           parent.episode_result_byte_count!=1200 || parent.phase_result_episode_id!=1))
          $fatal(1,"new live group episode must not overwrite immutable final identity/bounds/count aliases");
      end
      if(parent.episode_result_seq!=2 || parent.episode_result_episode_id!=2 ||
         parent.episode_result_byte_count!=120 || !parent.episode_result_e2e_valid ||
         parent.episode_result_e2e_gbps!=120 || parent.episode_last_steady_found ||
         parent.episode_last_steady_selection_valid)
        $fatal(1,"new group episode repeats its own e2e target; previous steady cannot substitute for missing representative");
    end
    $display("TB_PASS report_group_metrics mode=%s continued_after_conclusions=1",mode);$finish;
  end
endmodule
