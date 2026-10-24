module tb_group_config_errors;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string mode;
  int point_handle,group_handle;
  bw_u64_t point_width,point_stride,group_width;
  string point_clock,group_clock;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1),.EXPECTED_GROUP_COUNT(1),.STARTUP_TIMEOUT_NS(5)) setup();
  initial begin
    if(!$value$plusargs("MODE=%s",mode))$fatal(1,"MODE required");
    if(mode=="empty_id")define_group("",1);
    if(mode=="zero_members")define_group("g",0);
    if(mode=="unknown_member_count")define_group("g",32'hx0000001);
    if(mode=="wide_member_count")define_group("g",64'd4294967297);
    define_group("g",mode=="member_count" ? 2 : 1);
    if(mode=="duplicate_definition")define_group("g",1);
    if(mode=="extra_group")define_group("extra",1);
    point_width=(mode=="window" || mode=="stride") ? 2 : 1;
    point_stride=(mode=="stride") ? 2 : 1;
    group_width=(mode=="stride") ? 2 : 1;
    point_clock=(mode=="clock") ? "point_clock" : "default";
    group_clock=(mode=="clock") ? "group_clock" : "default";
    point_handle=register_point("p","component.point",BW_NS,point_width,point_stride,point_clock);
    if(mode!="missing_owner" && mode!="member_after_seal")begin
      group_handle=register_group_owner("g","component.group",BW_NS,group_width,1,group_clock);
      if(mode=="duplicate_owner")group_handle=register_group_owner("g","component.duplicate",BW_NS,1,1,"default");
    end
    if(mode=="unknown_rule")add_point_member("g","p",bw_match_t'(2'bxx));
    else if(mode=="missing_reference")add_point_member("g","typo");
    else if(mode=="prefix_empty")add_point_member("g","tb.noc1",BW_PREFIX);
    else if(mode!="empty_group")begin
      add_point_member("g","p");
      if(mode=="member_count")add_point_member("g","p");
    end
    if(mode!="missing_finish")finish_configuration();
    if(mode=="member_after_seal")add_point_member("g","p");
    if(mode=="hot_member" || mode=="late_registration" || mode=="repeat_finish")begin
      wait(monitor_ready);#1000;
      if(mode=="hot_member")add_point_member("g","p");
      if(mode=="late_registration")point_handle=register_point("late","component.late",BW_NS,1,1,"default");
      if(mode=="repeat_finish")finish_configuration();
    end
    #6000000;$fatal(1,"expected core error did not occur");
  end
endmodule
