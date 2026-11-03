// Ticket #49: omitted UPDATE_STRIDE defaults to W and omitted Q defaults to 10
// on points, groups and the shared core; explicit overrides and unused values
// keep the decided boundaries. One run covers all public entry kinds.
module tb_cfg_defaults;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic v_stride=0,v_cycle=0,v_silence=0,v_override=0,v_unused=0,v_unused_x=0;
  bw_u64_t e1,e2,c1,c6;
  bw_record_t core_frame='0;
  bit core_toggle=0;
  bw_u64_t core_results,core_window_end,core_total;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("cfg.stride.point"),.WINDOW_WIDTH(10),.FIXED_BYTES(8)) stride_point
    (.clk(clk),.reset_n(1'b1),.valid(v_stride));
  bw_point_mon #(.POINT_ID("cfg.stride.cycle"),.WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(4),.FIXED_BYTES(8)) cycle_point
    (.clk(clk),.reset_n(1'b1),.valid(v_cycle));
  bw_point_mon #(.POINT_ID("cfg.silence.ns"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .FIXED_BYTES(8),.EPISODE_ENABLE(1)) silence_ns_point
    (.clk(clk),.reset_n(1'b1),.valid(v_silence));
  bw_point_mon #(.POINT_ID("cfg.silence.cycle"),.WINDOW_BASIS(BW_CYCLE),
    .WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.FIXED_BYTES(8),.EPISODE_ENABLE(1)) silence_cycle_point
    (.clk(clk),.reset_n(1'b1),.valid(v_cycle));
  bw_point_mon #(.POINT_ID("cfg.silence.override"),.WINDOW_WIDTH(10),
    .FIXED_BYTES(8),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(20)) override_point
    (.clk(clk),.reset_n(1'b1),.valid(v_override));
  bw_point_mon #(.POINT_ID("cfg.silence.unused"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .FIXED_BYTES(8),.EPISODE_ENABLE(0),.SILENCE_THRESHOLD(0)) unused_point
    (.clk(clk),.reset_n(1'b1),.valid(v_unused));
  bw_point_mon #(.POINT_ID("cfg.silence.unused.x"),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .FIXED_BYTES(8),.EPISODE_ENABLE(0),.SILENCE_THRESHOLD(64'bx)) unused_x_point
    (.clk(clk),.reset_n(1'b1),.valid(v_unused_x));
  bw_group_mon #(.GROUP_ID("cfg.stride.group"),.WINDOW_WIDTH(10)) stride_group
    (.clk(clk),.reset_n(1'b1));
  bw_stats_core #(.WINDOW_WIDTH(10)) stride_core
    (.scope_id("cfg.stride.core"),.record(core_frame),.record_toggle(core_toggle),
     .result_seq(core_results),.window_end_ticks(core_window_end),.total_bytes(core_total));
  task automatic edge_at(bw_u64_t ticks);
    #(ticks+measurement_start_ticks-$time);clk=1;#1;clk=0;
  endtask
  initial begin
    add_point_member("cfg.stride.group","cfg.stride.point");
    wait(monitor_ready);
    fork
      begin
        wait(stride_point.result_seq>=1);e1=stride_point.window_end_ticks;
        wait(stride_point.result_seq>=2);e2=stride_point.window_end_ticks;
        if (e1!=measurement_start_ticks+ns_to_ticks(10) || e2-e1!=ns_to_ticks(10))
          $fatal(1,"omitted S must default to W for a point (ns basis)");
      end
      begin
        wait(cycle_point.result_seq>=1);c1=cycle_point.window_end_cycle;
        wait(cycle_point.result_seq>=6);c6=cycle_point.window_end_cycle;
        if (c1!=5 || c6-c1!=20)
          $fatal(1,"omitted S must default to W for a point (cycle basis)");
      end
      begin
        #(ns_to_ticks(14)-2);
        if (!silence_ns_point.episode_active || silence_ns_point.episode_result_seq!=0)
          $fatal(1,"default Q must be 10 ns, not shorter");
        #3;
        if (silence_ns_point.episode_active || silence_ns_point.episode_result_seq!=1 ||
            silence_ns_point.episode_result.status!=BW_EPISODE_COMPLETE ||
            silence_ns_point.episode_result.confirmation_ticks!=measurement_start_ticks+ns_to_ticks(14) ||
            silence_ns_point.episode_result.first_ticks!=measurement_start_ticks+ns_to_ticks(1) ||
            silence_ns_point.episode_result.last_ticks!=measurement_start_ticks+ns_to_ticks(3) ||
            silence_ns_point.episode_result.tail_ticks!=measurement_start_ticks+ns_to_ticks(4) ||
            silence_ns_point.episode_result.byte_count!=24 ||
            silence_ns_point.episode_result.event_count!=3 ||
            !silence_ns_point.episode_result.e2e_valid ||
            $abs(silence_ns_point.episode_result.e2e_gbps-8.0)>1e-9)
          $fatal(1,"default Q must complete the episode exactly at last edge + 10 ns");
      end
      begin
        #(ns_to_ticks(13)+2);
        if (!silence_cycle_point.episode_active || silence_cycle_point.episode_result_seq!=0)
          $fatal(1,"default Q must be ten local cycles, not fewer");
        #(ns_to_ticks(14)-ns_to_ticks(13));
        if (silence_cycle_point.episode_active || silence_cycle_point.episode_result_seq!=1 ||
            silence_cycle_point.episode_result.status!=BW_EPISODE_COMPLETE ||
            silence_cycle_point.episode_result.confirmation_ticks!=measurement_start_ticks+ns_to_ticks(14) ||
            silence_cycle_point.episode_result.first_cycle!=1 ||
            silence_cycle_point.episode_result.last_cycle!=3 ||
            silence_cycle_point.episode_result.tail_cycle!=4)
          $fatal(1,"default Q must complete the episode at tail cycle + 10 local cycles");
      end
      begin
        #(ns_to_ticks(15));
        if (!override_point.episode_active || override_point.episode_result_seq!=0)
          $fatal(1,"explicit Q=20 must not fall back to the 10 ns default");
        #(ns_to_ticks(24)-ns_to_ticks(15)+2);
        if (override_point.episode_active || override_point.episode_result_seq!=1 ||
            override_point.episode_result.confirmation_ticks!=measurement_start_ticks+ns_to_ticks(24))
          $fatal(1,"explicit Q>W must complete at its own deadline");
      end
      begin
        #(ns_to_ticks(5));
        if (unused_point.result_seq!=4 || unused_point.total_bytes!=24 ||
            unused_point.episode_active ||
            unused_x_point.result_seq!=4 || unused_x_point.total_bytes!=24 ||
            unused_x_point.episode_active)
          $fatal(1,"unused Q must stay unvalidated while episode analysis is off");
      end
      begin
        for (int t=1;t<=25;t++) begin
          #(measurement_start_ticks+ns_to_ticks(t)-$time);
          core_frame='0;core_frame.timestamp_ticks=measurement_start_ticks+ns_to_ticks(t);core_frame.edge_index=t;
          core_frame.record_seq=t;core_frame.reset_n=1'b1;core_frame.bytes_complete=1'b1;
          core_frame.events_complete=1'b1;core_frame.byte_inc=8;core_frame.event_inc=1;
          core_toggle<=!core_toggle;
        end
      end
    join_none
    for (int t=1;t<=25;t++) begin
      v_stride=1;v_cycle=(t<=3);v_silence=(t<=3);v_override=(t<=3);
      v_unused=(t<=3);v_unused_x=(t<=3);
      edge_at(ns_to_ticks(t));
    end
    wait fork;
    if (stride_point.result_seq!=2 || !stride_point.window_full ||
        stride_point.window_start_ticks!=measurement_start_ticks+ns_to_ticks(10) ||
        stride_point.window_bytes!=80 || $abs(stride_point.bandwidth_gbps-8.0)>1e-9 ||
        stride_point.total_bytes!=200)
      $fatal(1,"omitted S=W must keep exact 10 ns point windows");
    if (stride_group.result_seq!=2 || !stride_group.window_full ||
        stride_group.window_start_ticks!=measurement_start_ticks+ns_to_ticks(10) ||
        stride_group.window_bytes!=80 || stride_group.total_bytes!=200)
      $fatal(1,"omitted S=W must keep exact 10 ns group windows");
    if (core_results!=2 || core_window_end!=measurement_start_ticks+ns_to_ticks(20) || core_total!=200)
      $fatal(1,"omitted S=W must keep exact 10 ns core windows");
    if (cycle_point.result_seq!=6)
      $fatal(1,"omitted S=W must publish once per W cycles");
    $display("TB_PASS cfg_defaults");$finish;
  end
endmodule
