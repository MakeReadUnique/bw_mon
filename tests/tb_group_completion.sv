module tb_group_completion;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,point_reset_n=1,group0_reset_n=1;
  bit kick=0;
  string stage;
  bit damaged,source_failed_case;
  bw_u64_t expected_bytes;
  bw_u64_t receipts[8],ticks[8],bytes[8];
  import "DPI-C" context function int bw_test_observe_group_completion();
  function void bw_test_group_completion_observed();
    $display("TB_GROUP_TRACE stage=%s pbytes=%0d rawbytes=%0d peerevents=%0d peerbytes=%0d g3bytes=%0d rootbytes=%0d controls=%0d epoch=%0d/%0d",stage,p.total_bytes,p.raw_record.byte_inc,peer.total_events,peer.total_bytes,groups[3].mon.total_bytes,groups[7].mon.total_bytes,groups[7].mon.control_result_seq,p.stats_epoch,groups[3].mon.stats_epoch);
    if($time!=1000001 || scope_disabled(BW_POINT,"g0")!=source_failed_case || scope_disabled(BW_GROUP,"peer")!=source_failed_case ||
       (!source_failed_case && peer.total_bytes!=expected_bytes) || q.total_bytes!=16)
      $fatal(1,"original-time healthy peer differs");
    if(scope_disabled(BW_GROUP,"g0")!=damaged || scope_disabled(BW_GROUP,"g7")!=damaged)
      $fatal(1,"original-time hierarchy trust differs");
    if(damaged && (stage=="core" || stage=="control_core") &&
       (groups[0].mon.collector_running || !groups[0].mon.collector_cancelled || !groups[0].mon.core.scheduler_cancelled || groups[0].mon.core.scheduler_running))
      $fatal(1,"actual blocked collector/core worker did not exit cancellation at original time");
    if(damaged && (groups[0].mon.expected_edges.size()!=0 || !groups[0].mon.core.runtime_actions_cancelled ||
                   groups[0].mon.core.pending_frames.size()!=0 || groups[0].mon.core.pending_member_controls.size()!=0 || groups[0].mon.captured_resets.size()!=0))
      $fatal(1,"disabled group retained owned pending work instead of cancellation");
    if(damaged && monitoring_root_cause[scope_key(BW_GROUP,"g7")]!=scope_key(source_failed_case?BW_POINT:BW_GROUP,"g0"))
      $fatal(1,"same-name point/group failure root lost typed identity");
    if(!damaged)for(int g=0;g<8;g++)
      if(receipts[g]!=1 || ticks[g]!=1000001 || bytes[g]!=expected_bytes)$fatal(1,"eight-layer receipt/value differs g%0d",g);
    if(stage=="reactive")begin
      if(p.stats_epoch!=20 || groups[3].mon.stats_epoch!=20 || groups[3].mon.total_bytes!=0 || groups[7].mon.total_bytes!=0 || groups[7].mon.control_result_seq!=41)
        $fatal(1,"finite Reactive/ReNBA point/group resets lost raw/control supply");
      $display("TB_GROUP_RENBA assertions=20 point_controls=41 root_bytes=0 original_ticks=%0d",$time);
    end
    if(retained_frame_count(p.transport_source)!=0)$fatal(1,"completed/cancelled input responsibilities leaked");
    $display("TB_GROUP_READ_ONLY ticks=%0d damaged=%0b peer_bytes=%0d",$time,damaged,peer.total_bytes);
    if(stage=="reactive")begin $display("TB_PASS group_completion stage=reactive");$finish;end
  endfunction
  export "DPI-C" function bw_test_group_completion_observed;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("g0"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(8)) p
    (.clk(clk),.reset_n(point_reset_n),.valid(1'b1));
  bw_point_mon #(.POINT_ID("healthy"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(16)) q
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("peer"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) peer(.clk(clk),.reset_n(1'b1));
  for(genvar g=0;g<8;g++)begin: groups
    bw_group_mon #(.GROUP_ID($sformatf("g%0d",g)),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) mon
      (.clk(clk),.reset_n(g==0?group0_reset_n:(g==3?reset_n:1'b1)));
    assign receipts[g]=mon.accepted_record_seq;assign ticks[g]=mon.raw_record.timestamp_ticks;
    assign bytes[g]=mon.raw_record.byte_inc;
    always @(slot_settlement_generation or mon.raw_record or mon.accepted_record_seq)begin
      if(monitor_ready && !scope_disabled(BW_GROUP,mon.scope_id))
        for(int m=0;m<mon.direct_member_count;m++)
          if(acknowledged_frame_seq(mon.group_handle,m)>mon.accepted_record_seq ||
             acknowledged_frame_seq(mon.group_handle,m)>registered_sources[mon.transport_source].last_frame_seq)
            $fatal(1,"input ACK preceded durable local output/core receipt group=%0d",g);
    end
  end
  initial begin
    if(!$value$plusargs("STAGE=%s",stage))stage="none";
    source_failed_case=(stage=="source");
    expected_bytes=(stage=="reactive" || stage.substr(0,7)=="control_")?0:8;
    damaged=stage!="none" && stage!="notice" && stage!="reactive";
    add_point_member("g0","g0");add_point_member("peer","g0");
    for(int g=1;g<8;g++)add_group_member($sformatf("g%0d",g),$sformatf("g%0d",g-1));
    wait(monitor_ready);
    if(source_failed_case)inject_point_fault("g0","capture");
    else if(stage!="none" && stage!="reactive")inject_group_fault("g0",stage);
    #1000000;clk=1;if(stage=="reactive")kick<=1;
    if(stage.substr(0,7)=="control_")point_reset_n<=0;
    if(stage.substr(0,5)=="reset_")group0_reset_n<=0;
    if(!bw_test_observe_group_completion())$fatal(1,"cannot register read-only verifier");
    #1;clk=0;reset_n=0;point_reset_n=1;group0_reset_n=1;
    #1000000;reset_n=1;clk=1;#1;
    if(q.total_bytes!=32 || scope_disabled(BW_POINT,"healthy") ||
       (!source_failed_case && (scope_disabled(BW_GROUP,"peer") || peer.total_bytes!=expected_bytes+8)) ||
       scope_disabled(BW_POINT,"g0")!=source_failed_case)$fatal(1,"healthy peer/source did not continue");
    if(damaged && !scope_disabled(BW_GROUP,"g0"))$fatal(1,"reset revived failure");
    #10000000;
    if(!source_failed_case && scope_disabled(BW_GROUP,"peer"))$fatal(1,"stopped clock invented an edge");
    $display("TB_PASS group_completion stage=%s",stage);$finish;
  end
  group_completion_driver driver();
endmodule
program group_completion_driver;
  initial begin
    @(posedge tb_group_completion.kick);
    repeat(20)begin
      tb_group_completion.point_reset_n<=0;tb_group_completion.reset_n<=0;
      @(tb_group_completion.point_reset_n);#0;
      tb_group_completion.point_reset_n<=1;tb_group_completion.reset_n<=1;
      @(tb_group_completion.point_reset_n);#0;
    end
  end
endprogram
