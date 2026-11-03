module tb_phase_defaults;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, valid=1;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("defaults.phase"),.WINDOW_WIDTH(1),.FIXED_BYTES(100),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("defaults.episode"),.WINDOW_WIDTH(1),.FIXED_BYTES(100),.EPISODE_ENABLE(1),.PHASE_ENABLE(0)) episode_only
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("defaults.off"),.WINDOW_WIDTH(1),.FIXED_BYTES(100)) disabled
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_point_mon #(.POINT_ID("defaults.explicit"),.WINDOW_WIDTH(1),.FIXED_BYTES(100),.EPISODE_ENABLE(1),.PHASE_ENABLE(1)) explicit_phase
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_group_mon #(.GROUP_ID("defaults.group"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("defaults.group_episode"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1),.PHASE_ENABLE(0)) group_episode
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("defaults.group_off"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(0),.PHASE_ENABLE(0)) group_off
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("defaults.group_explicit"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1),.PHASE_ENABLE(1)) group_explicit
    (.clk(clk),.reset_n(1'b1));
  bw_phase_t core_phase;
  bw_stats_core #(.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) core_default
    (.scope_id("defaults.core"),.record(point.raw_record),.record_toggle(point.record_toggle),.phase_current(core_phase));
  initial begin
    add_point_member("defaults.group_episode","defaults.phase");
    add_point_member("defaults.group_off","defaults.phase");
    add_point_member("defaults.group_explicit","defaults.phase");
  end
  initial add_point_member("defaults.group","defaults.phase");
  initial begin
    wait(monitor_ready);
    #1;
    if(point.phase_reason!=BW_PHASE_NO_EPISODE || episode_only.phase_reason!=BW_PHASE_DISABLED ||
       disabled.phase_reason!=BW_PHASE_DISABLED || point.phase_evidence_required!=6 ||
       group_mon.phase_candidate_required!=2 || point.phase_minimum_span!=1)
      $fatal(1,"public phase explanation must distinguish disabled/no episode and show fixed requirements");
    for(int update=1;update<=9;update++)begin
      #500000;clk=1;#1;clk=0;#500000;
      if(update==6 && (point.phase_current!=BW_PHASE_UNDETERMINED ||
          point.phase_candidate_count!=1 || group_mon.phase_candidate_count!=1 ||
          point.phase_reason!=BW_PHASE_CONFIRMING))
        $fatal(1,"six complete windows establish a candidate; confirmation requires two updates");
      if(update==7 && (point.phase_current!=BW_PHASE_STEADY || group_mon.phase_current!=BW_PHASE_STEADY ||
          explicit_phase.phase_current!=BW_PHASE_STEADY || group_explicit.phase_current!=BW_PHASE_STEADY ||
          core_phase!=BW_PHASE_STEADY || point.phase_start_ticks!=measurement_start_ticks+6000000 ||
          point.phase_confirmation_ticks!=measurement_start_ticks+7000000 ||
          point.phase_reason!=BW_PHASE_CONFIRMED))
        $fatal(1,"default point and group must confirm the constant platform at update seven");
    end
    if(!episode_only.episode_active || episode_only.phase_id!=0 || disabled.episode_id!=0 || disabled.phase_id!=0 ||
       !group_episode.episode_active || group_episode.phase_id!=0 || group_off.episode_id!=0 || group_off.phase_id!=0)
      $fatal(1,"episode-only and disabled controls must remain independent");
    $display("TB_PASS phase_defaults");$finish;
  end
endmodule
