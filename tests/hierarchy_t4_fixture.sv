module hierarchy_t4_fixture #(parameter bw_mon_pkg::bw_basis_t BASIS=bw_mon_pkg::BW_NS);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  localparam bw_u64_t W=(BASIS==BW_NS) ? 10 : 20;
  localparam bw_u64_t S=(BASIS==BW_NS) ? 1 : 2;
  logic clk=0,child_reset_n=1,parent_reset_n=1;
  logic [11:0] point_reset_n='1;
  logic [63:0] size_bytes[12];
  bw_u64_t point_totals[12],point_epochs[12];
  real point_bandwidths[12];
  string mode;
  bw_u64_t expected_child_bytes,expected_all_bytes,expected_mixed_bytes;
  bw_u64_t expected_child_events,expected_all_events,expected_mixed_events,missing_bytes;
  bit reset_case,size_case;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(12),.EXPECTED_GROUP_COUNT(4)) setup();
  for(genvar p=0;p<12;p++)begin: points
    bw_point_mon #(.POINT_ID($sformatf("p%0d",p)),.PROTOCOL(bw_protocol_t'(p%3)),
      .DYNAMIC_BYTES(p%2==0),.FIXED_BYTES(64),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(W),.UPDATE_STRIDE(S),
      .CREDIT_ENABLE(p%3==2),.CREDIT_CAPACITY(16),.CREDIT_INITIAL(16),.CREDIT_INITIAL_KNOWN(1)) mon
      (.clk(clk),.reset_n(point_reset_n[p]),.valid(1'b1),.ready(1'b1),.flitv(1'b1),.lcrdv(1'b1),
       .size_bytes(size_bytes[p]),.size_known(1'b1));
    assign point_totals[p]=mon.total_bytes;
    assign point_epochs[p]=mon.stats_epoch;
    assign point_bandwidths[p]=mon.bandwidth_gbps;
  end
  bw_group_mon #(.GROUP_ID("die0_dmc"),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(W),.UPDATE_STRIDE(S)) die0
    (.clk(clk),.reset_n(child_reset_n));
  bw_group_mon #(.GROUP_ID("die1_dmc"),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(W),.UPDATE_STRIDE(S)) die1
    (.clk(clk),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("all_dmc"),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(W),.UPDATE_STRIDE(S)) all_dmc
    (.clk(clk),.reset_n(parent_reset_n));
  bw_group_mon #(.GROUP_ID("mixed"),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(W),.UPDATE_STRIDE(S)) mixed
    (.clk(clk),.reset_n(1'b1));
  initial begin
    foreach(size_bytes[p])size_bytes[p]=64;
    if(!$value$plusargs("MODE=%s",mode))mode="normal";
    if(!(mode inside {"normal","child_reset","point_reset","size_unknown","parent_reset"}))$fatal(1,"bad MODE");
    define_group("all_dmc",2);define_group("mixed",3);define_group("die1_dmc",4);define_group("die0_dmc",4);
    add_group_member("all_dmc","die0_dmc");add_group_member("all_dmc","die1_dmc");
    add_group_member("mixed","die0_dmc");add_point_member("mixed","p8");add_point_member("mixed","p9");
    for(int p=0;p<4;p++)add_point_member("die0_dmc",$sformatf("p%0d",p));
    for(int p=4;p<8;p++)add_point_member("die1_dmc",$sformatf("p%0d",p));
    finish_configuration();wait(monitor_ready);
    #102000001;
    if(die0.direct_member_count!=4 || die1.recursive_point_count!=4 ||
       all_dmc.direct_member_count!=2 || all_dmc.recursive_point_count!=8 ||
       mixed.direct_member_count!=3 || mixed.recursive_point_count!=6 ||
       !die0.window_valid || !all_dmc.window_valid || !mixed.window_valid ||
       $abs(die0.bandwidth_gbps-512.0)>1e-10 || $abs(die1.bandwidth_gbps-512.0)>1e-10 ||
       $abs(all_dmc.bandwidth_gbps-1024.0)>1e-10 || $abs(mixed.bandwidth_gbps-768.0)>1e-10 ||
       (BASIS==BW_CYCLE && ($abs(die0.bytes_per_cycle-256.0)>1e-10 ||
        $abs(all_dmc.bytes_per_cycle-512.0)>1e-10 || $abs(mixed.bytes_per_cycle-384.0)>1e-10)))
      $fatal(1,"T4 full-window 2GHz/64B reference or direct/recursive cardinality failed");
    foreach(point_bandwidths[p])if($abs(point_bandwidths[p]-128.0)>1e-10)
      $fatal(1,"point p%0d including ungrouped points must independently measure 128GB/s",p);
    #(103900000-$time);
    if(mode=="child_reset")child_reset_n=0;
    if(mode=="parent_reset")parent_reset_n=0;
    if(mode=="point_reset")point_reset_n[0]=0;
    if(mode=="size_unknown")size_bytes[0]='x;
    #(104000001-$time);
    reset_case=(mode=="point_reset");size_case=(mode=="size_unknown");
    missing_bytes=(reset_case || size_case) ? 64 : 0;
    expected_child_bytes=(reset_case || size_case) ? 192 : 256;
    expected_all_bytes=(reset_case || size_case) ? 448 : 512;
    expected_mixed_bytes=(reset_case || size_case) ? 320 : 384;
    expected_child_events=reset_case ? 3 : 4;
    expected_all_events=reset_case ? 7 : 8;
    expected_mixed_events=reset_case ? 5 : 6;
    if(die0.raw_record.byte_inc!=expected_child_bytes || die0.raw_record.event_inc!=expected_child_events ||
       all_dmc.raw_record.byte_inc!=expected_all_bytes || all_dmc.raw_record.event_inc!=expected_all_events ||
       mixed.raw_record.byte_inc!=expected_mixed_bytes || mixed.raw_record.event_inc!=expected_mixed_events ||
       die1.raw_record.byte_inc!=256 || die1.raw_record.event_inc!=4)
      $fatal(1,"T5-E1 %s raw increments at104ns differ: child=%0d/%0d all=%0d/%0d mixed=%0d/%0d",mode,
        die0.raw_record.byte_inc,die0.raw_record.event_inc,all_dmc.raw_record.byte_inc,all_dmc.raw_record.event_inc,
        mixed.raw_record.byte_inc,mixed.raw_record.event_inc);
    if(die0.raw_record.timestamp_ticks!=104000000 || all_dmc.raw_record.timestamp_ticks!=104000000 ||
       mixed.raw_record.timestamp_ticks!=104000000 || die0.raw_record.edge_index!=208 ||
       all_dmc.raw_record.edge_index!=208 || mixed.raw_record.edge_index!=208 ||
       die0.raw_record.record_seq!=208 || all_dmc.raw_record.record_seq!=208 || mixed.raw_record.record_seq!=208 ||
       die0.accepted_record_seq!=208 || all_dmc.accepted_record_seq!=208 || mixed.accepted_record_seq!=208 ||
       die0.raw_record.source_epoch!=0 || all_dmc.raw_record.source_epoch!=0 || mixed.raw_record.source_epoch!=0 ||
       points[0].mon.raw_record.source_epoch!=bw_u64_t'(reset_case) || points[0].mon.raw_record.record_seq!=208)
      $fatal(1,"hierarchy must keep T104/edge208/source sequence across local statistics epochs");
    if(die0.raw_record.bytes_complete==size_case || all_dmc.raw_record.bytes_complete==size_case ||
       mixed.raw_record.bytes_complete==size_case || !die0.raw_record.events_complete ||
       !all_dmc.raw_record.events_complete || !mixed.raw_record.events_complete ||
       die0.raw_record.reset_points!=bw_u64_t'(reset_case) || all_dmc.raw_record.reset_points!=bw_u64_t'(reset_case) ||
       mixed.raw_record.reset_points!=bw_u64_t'(reset_case))
      $fatal(1,"T5-E1 byte/event completeness and actual-point reset coverage must remain independent");
    if(die0.total_bytes!=((mode=="child_reset") ? 0 : 53248-missing_bytes) ||
       all_dmc.total_bytes!=((mode=="parent_reset") ? 0 : 106496-missing_bytes) ||
       mixed.total_bytes!=79872-missing_bytes || die1.total_bytes!=53248 ||
       die0.stats_epoch!=bw_u64_t'(mode=="child_reset") ||
       all_dmc.stats_epoch!=bw_u64_t'(mode=="parent_reset") || mixed.stats_epoch!=0 ||
       point_epochs[0]!=bw_u64_t'(reset_case) || point_totals[10]!=13312 || point_totals[11]!=13312)
      $fatal(1,"statistics reset must affect only its own history while ancestor/peer supply continues");
    if(retained_frame_count(die0.transport_source)!=0 ||
       acknowledged_frame_seq(all_dmc.group_handle,0)!=208 || acknowledged_frame_seq(mixed.group_handle,0)!=208 ||
       acknowledged_frame_seq(die0.group_handle,0)!=208)
      $fatal(1,"all automatic direct consumers must acknowledge accepted durable source records");
    #(104100000-$time);child_reset_n=1;parent_reset_n=1;point_reset_n[0]=1;size_bytes[0]=64;
    #(105000001-$time);
    if(mode!="parent_reset" && (all_dmc.window_bytes!=10240-missing_bytes ||
       all_dmc.window_events!=(reset_case ? 159 : 160) || !all_dmc.window_full ||
       all_dmc.bytes_complete==size_case || all_dmc.member_reset_coverage!=reset_case))
      $fatal(1,"parent exact window must retain child history/reset coverage independently of child warmup");
    if(mixed.window_bytes!=7680-missing_bytes || mixed.window_events!=(reset_case ? 119 : 120) ||
       !mixed.window_full || mixed.bytes_complete==size_case || mixed.member_reset_coverage!=reset_case)
      $fatal(1,"second parent must retain its independent exact history and quality");
    if(mode=="child_reset" && (die0.total_bytes!=512 || !die0.window_warmup || all_dmc.total_bytes!=107520))
      $fatal(1,"child rewarmup cannot interrupt parent raw accumulation");
    if(mode=="parent_reset" && (all_dmc.total_bytes!=1024 || mixed.total_bytes!=80640 ||
       all_dmc.raw_record.byte_inc!=512 || die0.stats_epoch!=0))
      $fatal(1,"upper reset cannot reset shared child, other parent or upper raw publication");
    $display("TB_PASS hierarchy_t4 basis=%0d mode=%s T104 child=%0d/%0d all=%0d/%0d mixed=%0d/%0d",BASIS,mode,
      expected_child_bytes,expected_child_events,expected_all_bytes,expected_all_events,expected_mixed_bytes,expected_mixed_events);
    $finish;
  end
  initial begin
    wait(monitor_ready);#500000;
    forever begin clk=1;#250000;clk=0;#250000;end
  end
endmodule
