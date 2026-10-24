module tb_reset_member_controls;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, point_reset_n=1, scope_reset_n=1;
  bw_u64_t group_epoch, group_seq, group_total, group_bytes, group_start, group_end;
  bw_u64_t accepted_frame, accepted_controls;
  bit group_complete, group_reset_coverage, group_full;
  real group_gbps;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("member.point"), .WINDOW_WIDTH(4), .UPDATE_STRIDE(1),
    .FIXED_BYTES(8)) point (.clk(clk), .reset_n(point_reset_n), .valid(1'b1));
  // This exercises the already agreed normalized core/control boundary.
  // Actual group topology, transport and collector integration are tickets18/19.
  bw_stats_core #(.WINDOW_WIDTH(4), .UPDATE_STRIDE(1)) aggregate_scope
    (.scope_id("independent.scope"), .record(point.raw_record), .record_toggle(point.record_toggle),
     .stats_reset_n(scope_reset_n), .member_control(point.raw_control),
     .member_control_toggle(point.control_toggle), .accepted_record_seq(accepted_frame),
     .accepted_control_count(accepted_controls), .stats_epoch(group_epoch), .result_seq(group_seq),
     .total_bytes(group_total), .window_bytes(group_bytes), .window_start_ticks(group_start),
     .window_end_ticks(group_end), .bytes_complete(group_complete),
     .member_reset_coverage(group_reset_coverage), .window_full(group_full), .bandwidth_gbps(group_gbps));
  initial begin
    wait(monitor_ready);
    #250000; clk=1; #1; clk=0;
    #1249999; point_reset_n=0;
    #500001;
    if (group_epoch!=0 || group_total!=8 || group_bytes!=8 ||
        !group_complete || !group_reset_coverage || group_start!=0 || group_end!=2000000)
      $fatal(1,"member no-edge reset must retain ancestor history and mark known reset coverage");
    #249999; scope_reset_n=0;
    #250000; scope_reset_n=1;
    #1000000; point_reset_n=1;
    #1;
    if (group_epoch!=1 || group_bytes!=0 || !group_complete || !group_reset_coverage ||
        group_start!=2500000 || group_end!=3500000 || point.stats_epoch!=1 ||
        point.raw_control.control_seq!=3 || accepted_controls!=3 || accepted_frame!=1)
      $fatal(1,"own reset must preserve current member reset state and independent transport positions");
    #249999; clk=1; #1; clk=0;
    #750000;
    if (group_epoch!=1 || group_total!=8 || group_bytes!=8 || !group_complete ||
        !group_reset_coverage || group_start!=2500000 || group_end!=4500000 ||
        $abs(group_gbps-4.0)>1e-10 || point.total_bytes!=8 ||
        point.raw_record.record_seq!=2 || point.raw_record.source_epoch!=1 || accepted_frame!=2)
      $fatal(1,"member release must contribute immediately without resetting the ancestor schedule");
    #3000000;
    if (!group_full || group_start!=3500000 || group_end!=7500000 ||
        group_reset_coverage || !group_complete)
      $fatal(1,"closed member reset interval must expire at the exact left boundary");
    #499999; point_reset_n=1'bx;
    #500001;
    if (group_epoch!=1 || group_complete || group_total!=8 ||
        group_reset_coverage || accepted_controls!=4 || accepted_frame!=2 ||
        point.raw_record.record_seq!=2)
      $fatal(1,"member unknown reset without clocks must mark a gap without clearing totals or adding frames");
    $display("TB_PASS reset_member_controls"); $finish;
  end
endmodule
