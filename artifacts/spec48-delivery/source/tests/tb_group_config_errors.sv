module tb_group_config_errors;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string mode;
  int point_handle,group_handle;
  bw_u64_t point_width,point_stride,group_width;
  bw_mon_setup setup();
  initial begin
    if(!$value$plusargs("MODE=%s",mode))$fatal(1,"MODE required");
    point_width=(mode=="window" || mode=="stride") ? 2 : 1;
    point_stride=(mode=="stride") ? 2 : 1;
    group_width=(mode=="stride") ? 2 : 1;
    point_handle=register_point("p","component.point",BW_NS,point_width,point_stride);
    if(mode!="missing_owner")begin
      group_handle=register_group_owner(mode=="empty_id" ? "" : "g","component.group",BW_NS,group_width,1);
      if(mode=="duplicate_owner")group_handle=register_group_owner("g","component.duplicate",BW_NS,1,1);
    end
    if(mode=="unknown_rule")add_point_member("g","p",bw_match_t'(2'bxx));
    else if(mode=="missing_reference")add_point_member("g","typo");
    else if(mode=="prefix_empty")add_point_member("g","tb.noc1",BW_PREFIX);
    else if(mode!="empty_group")begin
      add_point_member("g","p");
    end
    if(mode=="member_after_seal")begin
      wait(configuration_sealed);add_point_member("g","p");
    end
    if(mode=="hot_member" || mode=="late_registration")begin
      wait(monitor_ready);#1000;
      if(mode=="hot_member")add_point_member("g","p");
      if(mode=="late_registration")point_handle=register_point("late","component.late",BW_NS,1,1);
    end
    #6000000;$fatal(1,"expected core error did not occur");
  end
endmodule
