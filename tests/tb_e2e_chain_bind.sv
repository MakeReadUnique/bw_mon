// Ticket #57 slice: the complete type-bind functional chain. Points attach to
// an existing DUT module type through one bind statement; every actual
// instance is discovered without counts, the named group aggregates two bound
// points through their stable auto path IDs, and the same public chain — auto
// start, metering, default phase analysis, default 5% checker, isolation and
// the one report-complete marker — is verified end to end.
module chain_link #(parameter int BEAT=16) (input logic clk, input logic valid);
  logic ready=1'b1;
  logic [63:0] beat_bytes;
  assign beat_bytes=BEAT;
  logic unused=valid;
endmodule

module tb_e2e_chain_bind;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  int ready_count=0,updates=24,inject_at=0;
  bit isolate=0;
  for(genvar i=0;i<3;i++)begin:links
    chain_link #(.BEAT(48-16*i)) link(.clk(clk),.valid(valid));
  end
  bind chain_link bw_point_mon #(.PROTOCOL(bw_mon_pkg::BW_VALID_READY),.DYNAMIC_BYTES(1),
    .WINDOW_WIDTH(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) u_bw
    (.clk(clk),.reset_n(1'b1),.valid(valid),.ready(ready),
     .size_bytes(beat_bytes),.size_known(1'b1));
  bw_mon_setup setup();
  bw_group_mon #(.GROUP_ID("bind.g"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1),
    .SILENCE_THRESHOLD(2)) g(.clk(clk),.reset_n(1'b1));
  always @(monitor_ready) if(monitor_ready)ready_count++;
  initial begin
    // Auto path IDs of bound instances are the stable public identities the
    // t=0 member rules reference; no manual count is involved.
    add_point_member("bind.g","tb_e2e_chain_bind.links[0].link.u_bw");
    add_point_member("bind.g","tb_e2e_chain_bind.links[1].link.u_bw");
  end
  initial begin
    bw_report_summary_t summary;
    void'($value$plusargs("ISOLATE=%d",inject_at));
    isolate=inject_at!=0;
    wait(monitor_ready);
    if(ready_count!=1 || measurement_start_ticks==0)
      $fatal(1,"the bind chain must auto start exactly once with a published origin");
    if(registered_scope_count(BW_POINT)!=3 || registered_scope_count(BW_GROUP)!=1 ||
       g.direct_member_count!=2)
      $fatal(1,"every actual bind instance must be discovered without counts");
    if(links[0].link.u_bw.scope_id!="tb_e2e_chain_bind.links[0].link.u_bw" ||
       links[2].link.u_bw.scope_id!="tb_e2e_chain_bind.links[2].link.u_bw")
      $fatal(1,"auto path identities must stay stable for member references");
    for(int update=1;update<=40;update++)begin
      valid=update<=updates;
`ifdef BW_MON_TEST_FAULTS
      if(isolate && update==inject_at)
        inject_growth_failure("tb_e2e_chain_bind.links[2].link.u_bw","recorder.samples");
`endif
      #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
      if(update==7)begin
        #(measurement_start_ticks+7000001-$time);
        if(links[0].link.u_bw.phase_current!=BW_PHASE_STEADY || links[0].link.u_bw.phase_id!=1 ||
           g.phase_current!=BW_PHASE_STEADY)
          $fatal(1,"live phase state must confirm the bound platforms at update seven");
      end
    end
    if(links[0].link.u_bw.episode_active || links[1].link.u_bw.episode_active ||
       (!isolate && links[2].link.u_bw.episode_active) || g.episode_active)
      $fatal(1,"episodes must close inside the driven observation window");
    if(links[0].link.u_bw.total_bytes!=48*updates || links[1].link.u_bw.total_bytes!=32*updates ||
       (!isolate && links[2].link.u_bw.total_bytes!=16*updates) || g.total_bytes!=(48+32)*updates)
      $fatal(1,"bound metering differs from the independent byte model");
    if(g.episode_result.byte_count!=(48+32)*updates || g.episode_result.duration_ticks!=24000000 ||
       !g.episode_result.e2e_valid || $abs(g.episode_result.e2e_gbps-80.0)>1e-10)
      $fatal(1,"bound group end-to-end aggregation differs from the independent model");
    if(links[0].link.u_bw.phase_result.phase_kind!=BW_PHASE_STEADY ||
       links[0].link.u_bw.phase_result.start_ticks!=measurement_start_ticks+6000000 ||
       links[0].link.u_bw.phase_result.confirmation_ticks!=measurement_start_ticks+7000000 ||
       links[0].link.u_bw.phase_result.byte_count!=18*48 || g.phase_result.phase_kind!=BW_PHASE_STEADY ||
       g.phase_result.byte_count!=18*(48+32))
      $fatal(1,"default phase analysis must confirm the bound constant platforms");
`ifdef BW_MON_TEST_FAULTS
    if(isolate)begin
      if(!scope_disabled(BW_POINT,"tb_e2e_chain_bind.links[2].link.u_bw"))
        $fatal(1,"the isolated bound scope must be quarantined");
      if(scope_disabled(BW_POINT,"tb_e2e_chain_bind.links[0].link.u_bw") ||
         scope_disabled(BW_POINT,"tb_e2e_chain_bind.links[1].link.u_bw") ||
         scope_disabled(BW_GROUP,"bind.g"))
        $fatal(1,"the storage failure must not leak into healthy bound scopes");
    end
`endif
    summary=check_report_summary();
    if(summary.fail_count!=0 || summary.pass_count!=(isolate ? 3 : 4))
      $fatal(1,"bound constant platforms must each pass the default checker pass=%0d",
        summary.pass_count);
    $display("TB_PASS e2e_chain_bind isolate=%0d group_bytes=%0d ungrouped_bytes=%0d pass=%0d",
      isolate,g.total_bytes,links[2].link.u_bw.total_bytes,summary.pass_count);
    $finish;
  end
endmodule
