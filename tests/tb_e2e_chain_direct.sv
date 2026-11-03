// Ticket #57 slice: the complete direct-instantiation functional chain over
// the public surface only — one parameterless setup, named points and a real
// named group instance with t=0 member rules; automatic start, exact raw
// metering, default PAIR6_R2 phase analysis, the default 5% sustained
// variation checker, and the one final report. The ISOLATE leg adds runtime
// fault isolation of one scope and proves the survivors keep exact results.
module tb_e2e_chain_direct;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid_a=0,valid_b=0,valid_c=0;
  int ready_count=0,updates=24,inject_at=0;
  bit isolate=0;
  bw_mon_setup setup();
  // Handshake point with explicit stride omission (S defaults to W) and an
  // explicit silence threshold.
  bw_point_mon #(.POINT_ID("chain.a"),.PROTOCOL(BW_VALID_READY),.FIXED_BYTES(64),
    .WINDOW_WIDTH(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) pa
    (.clk(clk),.reset_n(1'b1),.valid(valid_a),.ready(1'b1));
  // Valid-only point on the same chain.
  bw_point_mon #(.POINT_ID("chain.b"),.PROTOCOL(BW_VALID_ONLY),.FIXED_BYTES(32),
    .WINDOW_WIDTH(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) pb
    (.clk(clk),.reset_n(1'b1),.valid(valid_b));
  // Ungrouped point exercising the omitted silence default (Q=10).
  bw_point_mon #(.POINT_ID("chain.c"),.PROTOCOL(BW_VALID_ONLY),.FIXED_BYTES(16),
    .WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) pc
    (.clk(clk),.reset_n(1'b1),.valid(valid_c));
  // Real named group aggregating a and b; the group is its own declaration.
  bw_group_mon #(.GROUP_ID("chain.g"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1),
    .SILENCE_THRESHOLD(2)) g(.clk(clk),.reset_n(1'b1));
  always @(monitor_ready) if(monitor_ready)ready_count++;
  initial begin
    add_point_member("chain.g","chain.a");
    add_point_member("chain.g","chain.b");
  end
  initial begin
    bw_report_summary_t summary;
    bw_u64_t expect_total_a,expect_total_b,expect_total_g;
    void'($value$plusargs("ISOLATE=%d",inject_at));
    isolate=inject_at!=0;
    // Independent expectation: 24 constant one-byte-per-ns transfers per
    // point, group sums its two members, duration runs from the first
    // transfer edge to the sample edge after the last transfer.
    expect_total_a=64*updates;expect_total_b=32*updates;expect_total_g=expect_total_a+expect_total_b;
    wait(monitor_ready);
    if(ready_count!=1 || measurement_start_ticks==0)
      $fatal(1,"the chain must auto start exactly once with a published origin");
    if(registered_scope_count(BW_POINT)!=3 || registered_scope_count(BW_GROUP)!=1 ||
       g.direct_member_count!=2)
      $fatal(1,"scope and member counts must be discovered, not configured");
    for(int update=1;update<=40;update++)begin
      valid_a=update<=updates;valid_b=update<=updates;valid_c=update<=updates && !(isolate && update>inject_at);
`ifdef BW_MON_TEST_FAULTS
      // recorder.samples grows on every newly retained sample edge, so a
      // mid-run injection reliably reaches the guard; the coalescing event
      // history of a constant stream would not.
      if(isolate && update==inject_at)inject_growth_failure("chain.c","recorder.samples");
`endif
      #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
      if(update==7)begin
        // Live seam: the seventh update confirms the constant platform while
        // the episode is still active.
        #(measurement_start_ticks+7000001-$time);
        if(pa.phase_current!=BW_PHASE_STEADY || pa.phase_id!=1 ||
           pa.phase_confirmation_ticks!=measurement_start_ticks+7000000 ||
           g.phase_current!=BW_PHASE_STEADY)
          $fatal(1,"live phase state must confirm the constant platform at update seven");
      end
    end
    // Silence has closed every healthy episode: a/b/g after Q=2, the
    // omitted-default scope after its Q=10. A quarantined scope keeps its
    // frozen state instead of fabricating a normal close.
    if(pa.episode_active || pb.episode_active || (!isolate && pc.episode_active) ||
       g.episode_active)
      $fatal(1,"episodes must close inside the driven observation window");
    if(pa.total_bytes!=expect_total_a || pb.total_bytes!=expect_total_b ||
       (!isolate && pc.total_bytes!=16*updates) || g.total_bytes!=expect_total_g)
      $fatal(1,"chain metering differs from the independent byte model a=%0d b=%0d c=%0d g=%0d",
        pa.total_bytes,pb.total_bytes,pc.total_bytes,g.total_bytes);
    if(pa.episode_result.byte_count!=expect_total_a ||
       pa.episode_result.duration_ticks!=24000000 || !pa.episode_result.e2e_valid ||
       $abs(pa.episode_result.e2e_gbps-64.0)>1e-10)
      $fatal(1,"point a end-to-end result differs from the independent model");
    if(g.episode_result.byte_count!=expect_total_g ||
       g.episode_result.duration_ticks!=24000000 || !g.episode_result.e2e_valid ||
       $abs(g.episode_result.e2e_gbps-96.0)>1e-10)
      $fatal(1,"group end-to-end aggregation differs from the independent model");
    if(!isolate && (pc.episode_result.byte_count!=16*updates ||
       pc.episode_result.duration_ticks!=24000000 || !pc.episode_result.e2e_valid ||
       $abs(pc.episode_result.e2e_gbps-16.0)>1e-10))
      $fatal(1,"omitted-default scope end-to-end result differs from the independent model");
    // Default phase analysis: six eligible windows nominate, the seventh
    // confirms the constant platform. After the episode closes the confirmed
    // phase lives in the immutable final packet, not the live current field.
    if(pa.phase_result.phase_kind!=BW_PHASE_STEADY || pa.phase_result.episode_id!=1 ||
       pa.phase_result.result_seq==0 ||
       pa.phase_result.start_ticks!=measurement_start_ticks+6000000 ||
       pa.phase_result.confirmation_ticks!=measurement_start_ticks+7000000 ||
       pa.phase_result.byte_count!=18*64 || pa.phase_result.duration_ticks!=18500000 ||
       !pa.phase_result.bandwidth_valid ||
       $abs(pa.phase_result.bandwidth_gbps-real'(18*64)/18.5)>1e-10 ||
       pb.phase_result.phase_kind!=BW_PHASE_STEADY || g.phase_result.phase_kind!=BW_PHASE_STEADY ||
       g.phase_result.byte_count!=18*96 || $abs(g.phase_result.bandwidth_gbps-real'(18*96)/18.5)>1e-10 ||
       (!isolate && (pc.phase_result.phase_kind!=BW_PHASE_STEADY ||
                     pc.phase_result.byte_count!=18*16)))
      $fatal(1,"default phase analysis must confirm the constant platforms");
`ifdef BW_MON_TEST_FAULTS
    if(isolate)begin
      if(!scope_disabled(BW_POINT,"chain.c"))
        $fatal(1,"the isolated scope must be quarantined after its storage failure");
      if(scope_disabled(BW_POINT,"chain.a") || scope_disabled(BW_POINT,"chain.b") ||
         scope_disabled(BW_GROUP,"chain.g"))
        $fatal(1,"the storage failure must not leak into healthy scopes");
    end
`endif
    summary=check_report_summary();
    if(summary.fail_count!=0)
      $fatal(1,"constant chain platforms must not fail the default checker");
    if(!isolate && (summary.pass_count!=4 || summary.warning_count!=0))
      $fatal(1,"constant chain platforms must each pass the default checker pass=%0d warning=%0d",
        summary.pass_count,summary.warning_count);
    if(isolate && (summary.pass_count!=3 || summary.warning_count!=0))
      // Before $finish the quarantined scope has not yet settled its terminal
      // default-check row, so the in-run query sees only the three healthy
      // passes; the terminal NO_CONFIRMED_STEADY warnings appear in the final
      // BW_SUMMARY afterwards and are pinned by the case log expectations.
      $fatal(1,"isolated leg must keep the three healthy passes pre-finish pass=%0d warning=%0d",
        summary.pass_count,summary.warning_count);
    $display("TB_PASS e2e_chain_direct isolate=%0d bytes=%0d/%0d/%0d e2e=64/96GB/s phase=STEADY pass=%0d warning=%0d",
      isolate,pa.total_bytes,g.total_bytes,pc.total_bytes,summary.pass_count,summary.warning_count);
    if(isolate)
      $display("TB_PASS e2e_chain_direct quarantined=chain.c healthy_bytes=%0d/%0d/%0d",
        pa.total_bytes,pb.total_bytes,g.total_bytes);
    $finish;
  end
endmodule
