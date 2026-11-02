module tb_group_missing_ungrouped;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  int handle;
  bw_mon_setup setup();
  initial begin
    bw_report_summary_t summary;
    add_point_member("both","p0");add_point_member("both","p1");
    add_point_member("reuse","p0");
    handle=register_group_owner("both","component.both",BW_NS,1,1);
    handle=register_group_owner("reuse","component.reuse",BW_NS,1,1);
    handle=register_point("p0","component.p0",BW_NS,1,1);
    handle=register_point("p1","component.p1",BW_NS,1,1);
    // Three direct edges refer to only two actual points. Automatic discovery
    // must not infer a nonexistent third point from the sum of member counts.
    wait(monitor_ready);
    summary=check_report_summary();
    if(registered_scope_count(BW_POINT)!=2 || registered_scope_count(BW_GROUP)!=2 ||
       group_member_count(group_handle_for_id("both"))!=2 ||
       group_member_count(group_handle_for_id("reuse"))!=1 || summary.scopes_expected!=4)
      $fatal(1,"actual scope counts must be independent of repeated direct membership");
    $display("TB_PASS group_actual_scope");$finish;
  end
endmodule
