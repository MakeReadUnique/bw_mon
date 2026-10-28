// Small public integration tracer for the scalable acceptance harness.
module scale_tracer_scope #(parameter int CARDINALITY=1)(
  input logic [63:0] result_seq,accepted_record_seq,total_bytes,total_events,
  input logic [63:0] window_start_ticks,window_end_ticks,window_bytes,window_events,coverage_ticks,
  input real bandwidth_gbps,
  input bit full,warmup,bytes_complete,events_complete,valid,denominator_valid,member_reset,
  input bw_mon_pkg::bw_record_t raw_record
);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_u64_t windows=0,records=0;
  always @(accepted_record_seq) if(monitor_ready && accepted_record_seq!=0)begin
    records++;
    if(accepted_record_seq!=records || raw_record.record_seq!=records || raw_record.edge_index!=records ||
       raw_record.timestamp_ticks!=measurement_start_ticks+250000+(records-1)*500000 || raw_record.byte_inc!=64*CARDINALITY ||
       raw_record.event_inc!=CARDINALITY || !raw_record.bytes_complete || !raw_record.events_complete ||
       raw_record.reset_points!=0 || total_bytes!=64*CARDINALITY*records || total_events!=CARDINALITY*records)
      $fatal(1,"TRACER_RAW_MISMATCH scope=%m seq=%0d records=%0d bytes=%0d events=%0d",accepted_record_seq,records,total_bytes,total_events);
  end
  always @(result_seq) if(monitor_ready && result_seq!=0)begin
    bw_u64_t span,right,left,expected_bytes;
    windows++;right=windows*10000000;span=(windows<10)?right:100000000;left=right-span;right+=measurement_start_ticks;left+=measurement_start_ticks;
    expected_bytes=(span/500000)*64*CARDINALITY;
    if($test$plusargs("INJECT_CHECKER_ERROR") && windows==1)expected_bytes++;
    if(result_seq!=windows || window_start_ticks!=left || window_end_ticks!=right || coverage_ticks!=span ||
       window_bytes!=expected_bytes || window_events!=(span/500000)*CARDINALITY ||
       full!=(windows>=10) || warmup!=(windows<10) || !bytes_complete || !events_complete ||
       !denominator_valid || valid!=(windows>=10) || member_reset || $abs(bandwidth_gbps-128.0*CARDINALITY)>1e-10)
      $fatal(1,"TRACER_WINDOW_MISMATCH scope=%m seq=%0d bytes=%0d expected=%0d",result_seq,window_bytes,expected_bytes);
  end
endmodule

module tb_scale_tracer;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  initial begin wait(monitor_ready);forever #250000 clk=~clk;end
  for(genvar p=0;p<3;p++)begin:points
    bw_point_mon #(.POINT_ID($sformatf("trace.p%0d",p)),.PROTOCOL(bw_protocol_t'(p)),
      .FIXED_BYTES(64),.DYNAMIC_BYTES(p==1),.WINDOW_BASIS(BW_NS),.WINDOW_WIDTH(100),.UPDATE_STRIDE(10),
      .CREDIT_ENABLE(p==2),.CREDIT_CAPACITY(16),.CREDIT_INITIAL(16),.CREDIT_INITIAL_KNOWN(1),
      .CREDIT_RETURN_TIMING(BW_RETURN_NEXT_CYCLE),
      .BACKPRESSURE_ENABLE(p==1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(4),
      .SHORTAGE_ENABLE(p==2),.SHORTAGE_BASIS(BW_NS),.SHORTAGE_THRESHOLD(4),
      .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(30)) mon
      (.clk(clk),.reset_n(1'b1),.valid(1'b1),.ready(1'b1),.flitv(1'b1),.lcrdv(1'b1),.size_bytes(64'd64),.size_known(1'b1));
    scale_tracer_scope #(.CARDINALITY(1)) check_scope
      (.result_seq(mon.result_seq),.accepted_record_seq(mon.accepted_record_seq),.total_bytes(mon.total_bytes),.total_events(mon.total_events),
       .window_start_ticks(mon.window_start_ticks),.window_end_ticks(mon.window_end_ticks),.window_bytes(mon.window_bytes),.window_events(mon.window_events),
       .coverage_ticks(mon.coverage_ticks),.bandwidth_gbps(mon.bandwidth_gbps),.full(mon.window_full),.warmup(mon.window_warmup),
       .bytes_complete(mon.bytes_complete),.events_complete(mon.events_complete),.valid(mon.window_valid),.denominator_valid(mon.denominator_valid),
       .member_reset(mon.member_reset_coverage),.raw_record(mon.raw_record));
  end
  bw_group_mon #(.GROUP_ID("trace.child"),.WINDOW_WIDTH(100),.UPDATE_STRIDE(10),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(30)) child(.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("trace.parent"),.WINDOW_WIDTH(100),.UPDATE_STRIDE(10),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(30)) parent(.clk(clk),.reset_n(1'b1));
  scale_tracer_scope #(.CARDINALITY(2)) check_child
    (.result_seq(child.result_seq),
     .accepted_record_seq(child.accepted_record_seq),
     .total_bytes(child.total_bytes),
     .total_events(child.total_events),
     .window_start_ticks(child.window_start_ticks),
     .window_end_ticks(child.window_end_ticks),
     .window_bytes(child.window_bytes),
     .window_events(child.window_events),
     .coverage_ticks(child.coverage_ticks),
     .bandwidth_gbps(child.bandwidth_gbps),
     .full(child.window_full),
     .warmup(child.window_warmup),
     .bytes_complete(child.bytes_complete),
     .events_complete(child.events_complete),
     .valid(child.window_valid),
     .denominator_valid(child.denominator_valid),
     .member_reset(child.member_reset_coverage),
     .raw_record(child.raw_record));
  scale_tracer_scope #(.CARDINALITY(3)) check_parent
    (.result_seq(parent.result_seq),
     .accepted_record_seq(parent.accepted_record_seq),
     .total_bytes(parent.total_bytes),
     .total_events(parent.total_events),
     .window_start_ticks(parent.window_start_ticks),
     .window_end_ticks(parent.window_end_ticks),
     .window_bytes(parent.window_bytes),
     .window_events(parent.window_events),
     .coverage_ticks(parent.coverage_ticks),
     .bandwidth_gbps(parent.bandwidth_gbps),
     .full(parent.window_full),
     .warmup(parent.window_warmup),
     .bytes_complete(parent.bytes_complete),
     .events_complete(parent.events_complete),
     .valid(parent.window_valid),
     .denominator_valid(parent.denominator_valid),
     .member_reset(parent.member_reset_coverage),
     .raw_record(parent.raw_record));
  initial begin
    add_point_member("trace.child","trace.p0");add_point_member("trace.child","trace.p1");
    add_group_member("trace.parent","trace.child");add_point_member("trace.parent","trace.p2");
    wait(monitor_ready);
    if($time!=measurement_start_ticks || $time==0)$fatal(1,"tracer ready origin");
    #240000000;
    wait(check_child.windows==24 && check_parent.windows==24);
    if($time!=measurement_start_ticks+240000000 || check_child.records!=480 || check_parent.records!=480 ||
       points[0].check_scope.records!=480 || points[1].check_scope.records!=480 || points[2].check_scope.records!=480 ||
       points[0].check_scope.windows!=24 || points[1].check_scope.windows!=24 || points[2].check_scope.windows!=24 ||
       parent.total_bytes!=92160 || parent.total_events!=1440 || points[2].mon.credit_balance!=16 || !points[2].mon.credit_trusted ||
       points[1].mon.backpressure_hit_count!=0 || points[2].mon.shortage_hit_count!=0)
      $fatal(1,"tracer completion/credit/hint mismatch");
    $display("SCALE_TRACER_PASS scopes=5 windows=120 records=2400 tick=%0d start_ticks=%0d",$time,measurement_start_ticks);$finish;
  end
endmodule
