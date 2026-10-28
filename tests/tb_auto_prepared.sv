module tb_auto_prepared;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("prepared.held"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),
    .FIXED_BYTES(8),.PHASE_ENABLE(0),.PROTOCOL(BW_VALID_READY),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_CYCLE),.BACKPRESSURE_THRESHOLD(1)) held
    (.clk(clk),.reset_n(1'b0),.valid(1'b1),.ready(1'b0));
  bw_point_mon #(.POINT_ID("prepared.live"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),
    .FIXED_BYTES(16),.PHASE_ENABLE(0)) live_point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("prepared.group"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),
    .PHASE_ENABLE(0)) group_mon (.clk(clk),.reset_n(1'b0));
  initial begin
    bw_report_summary_t summary;
    add_point_member("prepared.group","prepared.held");
    wait(monitor_ready);
    // Ready promises usable public snapshots before traffic or clock activity.
    // There is deliberately no #0/#1 between ready and these observations.
    if (held.stats_epoch!=1 || held.raw_control.control_seq!=1 ||
        held.raw_control.source_epoch!=1 || held.raw_control.reset_n!==1'b0 ||
        group_mon.stats_epoch!=1 || group_mon.accepted_control_count!=1 ||
        group_mon.control_result_seq!=1 || group_mon.raw_control.source_epoch!=1)
      $fatal(1,"initial point/group reset snapshots must finish before ready");
    if (group_mon.direct_member_count!=1 || group_mon.recursive_point_count!=1)
      $fatal(1,"frozen group membership must be available at ready");
    if(held.backpressure_epoch!=1 || held.backpressure_trusted || held.backpressure_active)
      $fatal(1,"enabled hint reset state must be prepared before ready");
    if (held.result_seq!=0 || live_point.result_seq!=0 || group_mon.result_seq!=0 ||
        held.total_bytes!=0 || live_point.total_bytes!=0 || group_mon.total_bytes!=0)
      $fatal(1,"startup snapshots must not manufacture observations");
    summary=check_report_summary();
    if(summary.scopes_expected!=3 || summary.scopes_done!=0 || summary.finalized)
      $fatal(1,"all actual report scopes must be prepared before ready");
    if($time!=measurement_start_ticks || measurement_start_ticks==0)
      $fatal(1,"all preparation must finish in the published positive start slot");
    clk=1; #1; clk=0;
    if(live_point.total_bytes!=0) $fatal(1,"T edge must be excluded");
    #1; clk=1; #1; clk=0;
    if(live_point.total_bytes!=16 || live_point.raw_record.edge_index!=1 ||
        held.raw_record.edge_index!=1 || held.total_bytes!=0 || group_mon.total_bytes!=0)
      $fatal(1,"the first post-T edge must preserve initial reset and counting");
    $display("TB_PASS auto_prepared"); $finish;
  end
endmodule
