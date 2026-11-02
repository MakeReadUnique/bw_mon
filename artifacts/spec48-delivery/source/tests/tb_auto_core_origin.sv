module tb_auto_core_origin;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_u64_t core_end,core_coverage,core_bytes,core_sequence;
  bit core_full;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("origin.point"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(8),.PHASE_ENABLE(0)) point_mon
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("origin.group"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.PHASE_ENABLE(0)) group_mon
    (.clk(clk),.reset_n(1'b1));
  // Existing normalized core/control seam, alongside actual public monitors.
  bw_stats_core #(.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.PHASE_ENABLE(0)) extra_core
    (.scope_id("origin.component"),.record(point_mon.raw_record),.record_toggle(point_mon.record_toggle),
     .member_control(point_mon.raw_control),.member_control_toggle(point_mon.control_toggle),
     .stats_reset_n(1'b1),.window_end_ticks(core_end),.coverage_ticks(core_coverage),
     .window_bytes(core_bytes),.window_full(core_full),.result_seq(core_sequence));
  initial begin
    add_point_member("origin.group","origin.point");
    wait(monitor_ready);
    #500000;clk=1;#1;clk=0;
    #999999;clk=1;#1;clk=0;
    #500000;
    if(core_sequence!=2 || core_end!=measurement_start_ticks+2000000 ||
       core_coverage!=2000000 || core_bytes!=16 || !core_full ||
       point_mon.window_end_ticks!=measurement_start_ticks+2000000 || group_mon.window_bytes!=16)
      $fatal(1,"early member controls must not start a shared core schedule before common T");
    $display("TB_PASS auto_core_origin");$finish;
  end
endmodule
