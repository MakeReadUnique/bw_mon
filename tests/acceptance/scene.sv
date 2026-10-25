`define ACCEPT_ANALYSIS \
  .WINDOW_BASIS(BASIS),.WINDOW_WIDTH(BASIS==bw_mon_pkg::BW_NS ? 10 : 20), \
  .UPDATE_STRIDE(BASIS==bw_mon_pkg::BW_NS ? 1 : 2),.EPISODE_ENABLE(1), \
  .SILENCE_THRESHOLD(BASIS==bw_mon_pkg::BW_NS ? 12 : 24),.PHASE_ENABLE(1), \
  .PHASE_N(3),.PHASE_MIN_SPAN(BASIS==bw_mon_pkg::BW_NS ? 2 : 4),.PHASE_K(2), \
  .PHASE_STEADY_ENTER_ABS(0.01),.PHASE_STEADY_ENTER_REL(0.0), \
  .PHASE_STEADY_EXIT_ABS(0.01),.PHASE_STEADY_EXIT_REL(0.0), \
  .PHASE_RMS_ENTER_ABS(0.01),.PHASE_RMS_ENTER_REL(0.0), \
  .PHASE_RMS_EXIT_ABS(0.01),.PHASE_RMS_EXIT_REL(0.0), \
  .PHASE_TREND_ABS(5.0),.PHASE_TREND_REL(0.0)

module acceptance_observer #(parameter string NAME="")(
  input string scope_id,input logic scope_kind,
  input logic record_toggle,input bw_mon_pkg::bw_record_t raw_record,
  input logic [63:0] accepted_record_seq,result_seq,stats_epoch,total_bytes,
  input logic [63:0] window_start_ticks,window_end_ticks,window_start_cycle,window_end_cycle,
  input logic [63:0] coverage_ticks,coverage_cycles,window_bytes,window_events,
  input real bandwidth_gbps,bytes_per_cycle,
  input logic window_full,window_warmup,bytes_complete,events_complete,denominator_valid,member_reset_coverage,window_valid);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  integer fd;string directory;
  initial begin
    if(!$value$plusargs("OBS_DIR=%s",directory))directory=".";
    fd=$fopen({directory,"/",NAME,".csv"},"w");if(!fd)$fatal(1,"cannot open acceptance observation");
    wait(monitor_ready);$fdisplay(fd,"ID,%0d,%s,%s",scope_kind,scope_id,NAME);
  end
  always @(result_seq)if(monitor_ready && result_seq!=0)
    $fdisplay(fd,"W,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%.17g,%.17g,%0b,%0b,%0b,%0b,%0b,%0b,%0b",
      result_seq,stats_epoch,$time,window_start_ticks,window_end_ticks,window_start_cycle,window_end_cycle,
      coverage_ticks,coverage_cycles,window_bytes,window_events,bandwidth_gbps,bytes_per_cycle,
      window_full,window_warmup,bytes_complete,events_complete,denominator_valid,member_reset_coverage,window_valid);
  always @(record_toggle)if(monitor_ready && raw_record.record_seq!=0)
    $fdisplay(fd,"R,%0d,%0d,%0d,%0d,%0d,%0d,%0b,%0b,%0d,%b",raw_record.record_seq,
      raw_record.source_epoch,raw_record.timestamp_ticks,raw_record.edge_index,raw_record.byte_inc,
      raw_record.event_inc,raw_record.bytes_complete,raw_record.events_complete,raw_record.reset_points,raw_record.reset_n);
  always @(accepted_record_seq)if(monitor_ready && accepted_record_seq!=0)
    $fdisplay(fd,"A,%0d,%0d",accepted_record_seq,$time);
endmodule

`define ACCEPT_OBSERVER(VIEW,LABEL,MON) \
  acceptance_observer #(.NAME(LABEL)) VIEW(.scope_id(MON.scope_id),.scope_kind(MON.scope_kind), \
   .record_toggle(MON.record_toggle),.raw_record(MON.raw_record),.accepted_record_seq(MON.accepted_record_seq), \
   .result_seq(MON.result_seq),.stats_epoch(MON.stats_epoch),.total_bytes(MON.total_bytes), \
   .window_start_ticks(MON.window_start_ticks),.window_end_ticks(MON.window_end_ticks), \
   .window_start_cycle(MON.window_start_cycle),.window_end_cycle(MON.window_end_cycle), \
   .coverage_ticks(MON.coverage_ticks),.coverage_cycles(MON.coverage_cycles), \
   .window_bytes(MON.window_bytes),.window_events(MON.window_events),.bandwidth_gbps(MON.bandwidth_gbps), \
   .bytes_per_cycle(MON.bytes_per_cycle),.window_full(MON.window_full),.window_warmup(MON.window_warmup), \
   .bytes_complete(MON.bytes_complete),.events_complete(MON.events_complete),.denominator_valid(MON.denominator_valid), \
   .member_reset_coverage(MON.member_reset_coverage),.window_valid(MON.window_valid));

// DUT-facing wrapper: the bus encodes bytes-minus-one plus an explicit zero bit.
// Protocol controls stay visible; the reusable monitor receives decoded bytes.
module acceptance_port #(parameter int P=0,parameter logic [1:0] BASIS=bw_mon_pkg::BW_NS)(
  input logic clk,reset_n,valid,ready,flitv,lcrdv,
  input logic [31:0] byte_count_minus_one,input logic zero_bytes,input logic decode_known);
  timeunit 1fs;timeprecision 1fs;
  wire [63:0] accounted_bytes=zero_bytes ? 64'd0 : {32'd0,byte_count_minus_one}+64'd1;
  wire accounted_known=decode_known && !$isunknown({byte_count_minus_one,zero_bytes});
  `ACCEPT_OBSERVER(view,$sformatf("p%0d",P),mon)
endmodule
bind acceptance_port bw_point_mon #(.POINT_ID($sformatf("p%0d",P)),
  .PROTOCOL(bw_mon_pkg::bw_protocol_t'(P%3)),.DYNAMIC_BYTES(P%2==0),.FIXED_BYTES(64),
  .CREDIT_ENABLE(P%3==2),.CREDIT_CAPACITY(16),.CREDIT_INITIAL(16),.CREDIT_INITIAL_KNOWN(1),
  .BACKPRESSURE_ENABLE(P%3==1),.BACKPRESSURE_BASIS(bw_mon_pkg::BW_NS),.BACKPRESSURE_THRESHOLD(2),
  .SHORTAGE_ENABLE(P%3==2),.SHORTAGE_BASIS(bw_mon_pkg::BW_NS),.SHORTAGE_THRESHOLD(2),
  `ACCEPT_ANALYSIS) mon(.clk(clk),.reset_n(reset_n),.valid(valid),.ready(ready),.flitv(flitv),.lcrdv(lcrdv),
    .size_bytes(accounted_bytes),.size_known(accounted_known));

module acceptance_scene #(parameter logic [1:0] BASIS=bw_mon_pkg::BW_NS);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,child_reset_n=1,parent_reset_n=1;
  logic [11:0] point_reset_n='1,valid='0,ready='1,returns='0;
  logic [31:0] size_code[12];logic [11:0] zeros='0,size_known='1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(12),.EXPECTED_GROUP_COUNT(4)) setup();
  for(genvar p=0;p<12;p++)begin:ports
    acceptance_port #(.P(p),.BASIS(BASIS)) dut(.clk(clk),.reset_n(point_reset_n[p]),
      .valid(valid[p]),.ready(ready[p]),.flitv(valid[p]),.lcrdv(returns[p]),
      .byte_count_minus_one(size_code[p]),.zero_bytes(zeros[p]),.decode_known(size_known[p]));
  end
  bw_group_mon #(.GROUP_ID("die0_dmc"),`ACCEPT_ANALYSIS) die0(.clk(clk),.reset_n(child_reset_n));
  bw_group_mon #(.GROUP_ID("die1_dmc"),`ACCEPT_ANALYSIS) die1(.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("all_dmc"),`ACCEPT_ANALYSIS) all_dmc(.clk(clk),.reset_n(parent_reset_n));
  bw_group_mon #(.GROUP_ID("mixed"),`ACCEPT_ANALYSIS) mixed(.clk(clk),.reset_n(1'b1));
  `ACCEPT_OBSERVER(die0_view,"die0",die0)
  `ACCEPT_OBSERVER(die1_view,"die1",die1)
  `ACCEPT_OBSERVER(all_view,"all_dmc",all_dmc)
  `ACCEPT_OBSERVER(mixed_view,"mixed",mixed)
  initial begin
    define_group("die0_dmc",4);define_group("die1_dmc",4);define_group("all_dmc",2);define_group("mixed",3);
    for(int p=0;p<4;p++)add_point_member("die0_dmc",$sformatf("p%0d",p));
    for(int p=4;p<8;p++)add_point_member("die1_dmc",$sformatf("p%0d",p));
    add_group_member("all_dmc","die0_dmc");add_group_member("all_dmc","die1_dmc");
    add_group_member("mixed","die0_dmc");add_point_member("mixed","p8");add_point_member("mixed","p9");
    finish_configuration();
  end
  initial begin:dump
    string fsdb_path;
    if(!$value$plusargs("FSDB=%s",fsdb_path))$fatal(1,"FSDB path required");
    $fsdbDumpfile(fsdb_path);
    $fsdbDumpvars(1);
    $fsdbDumpvars(1,ports[0].dut,"+all");$fsdbDumpvars(1,ports[0].dut.mon,"+all");
    $fsdbDumpvars(1,ports[1].dut,"+all");$fsdbDumpvars(1,ports[1].dut.mon,"+all");
    $fsdbDumpvars(1,ports[2].dut,"+all");$fsdbDumpvars(1,ports[2].dut.mon,"+all");
    $fsdbDumpvars(1,ports[3].dut,"+all");$fsdbDumpvars(1,ports[3].dut.mon,"+all");
    $fsdbDumpvars(1,ports[4].dut,"+all");$fsdbDumpvars(1,ports[4].dut.mon,"+all");
    $fsdbDumpvars(1,ports[5].dut,"+all");$fsdbDumpvars(1,ports[5].dut.mon,"+all");
    $fsdbDumpvars(1,ports[6].dut,"+all");$fsdbDumpvars(1,ports[6].dut.mon,"+all");
    $fsdbDumpvars(1,ports[7].dut,"+all");$fsdbDumpvars(1,ports[7].dut.mon,"+all");
    $fsdbDumpvars(1,ports[8].dut,"+all");$fsdbDumpvars(1,ports[8].dut.mon,"+all");
    $fsdbDumpvars(1,ports[9].dut,"+all");$fsdbDumpvars(1,ports[9].dut.mon,"+all");
    $fsdbDumpvars(1,ports[10].dut,"+all");$fsdbDumpvars(1,ports[10].dut.mon,"+all");
    $fsdbDumpvars(1,ports[11].dut,"+all");$fsdbDumpvars(1,ports[11].dut.mon,"+all");
    $fsdbDumpvars(1,die0,"+all");
    $fsdbDumpvars(1,die1,"+all");
    $fsdbDumpvars(1,all_dmc,"+all");
    $fsdbDumpvars(1,mixed,"+all");
  end
  initial begin:drive
    integer fd,rc;string stimulus,line;bw_u64_t at_ticks,end_ticks;
    integer edge_flag,activity,readiness,credit_returns,reset_mask,reset_x,size_x,valid_x,child_level,parent_level;
    integer amount[12];
    if(!$value$plusargs("STIM=%s",stimulus))$fatal(1,"STIM input table required");
    if(!$value$plusargs("END_TICKS=%d",end_ticks))$fatal(1,"END_TICKS required");
    fd=$fopen(stimulus,"r");if(!fd)$fatal(1,"cannot open raw stimulus table");
    foreach(size_code[p])size_code[p]=63;
    wait(monitor_ready);
    while($fgets(line,fd))begin
      rc=$sscanf(line,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
       at_ticks,edge_flag,activity,readiness,credit_returns,reset_mask,reset_x,size_x,valid_x,child_level,parent_level,
       amount[0],amount[1],amount[2],amount[3],amount[4],amount[5],amount[6],amount[7],amount[8],amount[9],amount[10],amount[11]);
      if(rc!=23)$fatal(1,"malformed input table");
      if(at_ticks<(edge_flag ? $time+100 : $time))$fatal(1,"unordered input table");
      #(at_ticks-(edge_flag ? 100 : 0)-$time);
      valid=activity;ready=readiness;returns=credit_returns;point_reset_n=reset_mask;
      child_reset_n=child_level;parent_reset_n=parent_level;
      for(int p=0;p<12;p++)begin
        if((reset_x>>p)&1)point_reset_n[p]=1'bx;
        if((valid_x>>p)&1)valid[p]=1'bx;
        size_known[p]=!((size_x>>p)&1);zeros[p]=(amount[p]==0);
        size_code[p]=((size_x>>p)&1) ? 32'bx : amount[p]-1;
      end
      if(edge_flag)begin #100;clk=1;clk<=#250000 0;#1;end
    end
    $fclose(fd);#(end_ticks-$time);#1;
    $display("TB_PASS acceptance basis=%0d",BASIS);$finish;
  end
endmodule
module tb_acceptance_ns;
  timeunit 1fs;timeprecision 1fs;
  acceptance_scene #(.BASIS(bw_mon_pkg::BW_NS)) scene();
endmodule
module tb_acceptance_cycle;
  timeunit 1fs;timeprecision 1fs;
  acceptance_scene #(.BASIS(bw_mon_pkg::BW_CYCLE)) scene();
endmodule
`undef ACCEPT_OBSERVER
`undef ACCEPT_ANALYSIS
