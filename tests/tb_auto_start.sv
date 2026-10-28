// Ticket #50: automatic registration, named-group configuration and the one
// ready publication. No manual counts, no manual finish, no timeout knobs.
module tb_auto_start;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic v0=0,v1=0,v2=0;
  int ready_count=0;
  bw_mon_setup setup();
  // 点-only 与未归组点：p0 无组成员资格也进入统计与报告。
  bw_point_mon #(.POINT_ID("auto.p0"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p0
    (.clk(clk),.reset_n(1'b1),.valid(v0));
  bw_point_mon #(.POINT_ID("auto.p1"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p1
    (.clk(clk),.reset_n(1'b1),.valid(v1));
  bw_point_mon #(.POINT_ID("auto.p2"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p2
    (.clk(clk),.reset_n(1'b1),.valid(v2));
  // 前向引用目标：规则在 #0 链中先行，实例注册晚于规则到达。
  bw_point_mon #(.POINT_ID("auto.forward.leaf"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p3
    (.clk(clk),.reset_n(1'b1),.valid(v2));
  // 真实具名实例即组声明；ga/gb 共享 p1 形成多父。
  bw_group_mon #(.GROUP_ID("auto.ga"),.WINDOW_WIDTH(4)) ga (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("auto.gb"),.WINDOW_WIDTH(4)) gb (.clk(clk),.reset_n(1'b1));
  always @(monitor_ready) if (monitor_ready) ready_count++;
  task automatic edge_at(bw_u64_t ticks);
    #(ticks-$time);clk=1;#1;clk=0;
  endtask
  initial begin
    // t=0 有限同刻链：#0 排队的前向引用规则在封口前必须全部可解析。
    add_point_member("auto.ga","auto.p1");
    fork begin
      #0;
      add_point_member("auto.gb","auto.p1"); // 多父共享
      add_point_member("auto.gb","auto.p2");
      add_point_member("auto.ga","auto.forward.leaf"); // 前向引用：晚注册的点
    end join_none
    begin
      wait(monitor_ready);
      if (ready_count!=1) $fatal(1,"ready must be published exactly once");
      if (measurement_start_ticks!=1) $fatal(1,"T must be the actual first positive slot");
      if (registered_scope_count(BW_POINT)!=4 || registered_scope_count(BW_GROUP)!=2)
        $fatal(1,"actual scope counts must be derived automatically");
      // T 同刻沿排除：恰在 T=1fs 的沿与传输不进入计量。
      v0=1;
      #(1-$time); clk=1; #1; clk=0;
      if (p0.total_bytes!=0) $fatal(1,"an edge exactly at T must be excluded");
      // 首个合法计量沿严格晚于 T；p0 之后保持空闲。
      v0=0;v1=1;v2=1;
      edge_at(ns_to_ticks(2));
      v1=0;v2=0;
      edge_at(ns_to_ticks(3));
      if (p0.total_bytes!=0) $fatal(1,"p0 second edge is idle");
      if (p1.total_bytes!=8 || p2.total_bytes!=8) $fatal(1,"post-T edges must count");
      if (ga.total_bytes!=16 || gb.total_bytes!=16)
        $fatal(1,"multi-parent raw aggregation must match member leaves");
      if (ga.direct_member_count!=2 || gb.direct_member_count!=2)
        $fatal(1,"direct member counts must be derived automatically");
      $display("TB_PASS auto_start");$finish;
    end
  end
endmodule
