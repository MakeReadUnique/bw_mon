"""Public topology fixture. Reference depends on fixed input weights/leaf sets only."""
import csv
import json
import re
from generate import generate as legacy_generate
from run import verify as verify_streams, save


REFERENCE = r'''
  function automatic ref_u64 reset_begin(bit is_group,int index);
    if(index!=0)return 0;
    return is_group ? GROUP_RESET_START : RESET_START;
  endfunction
  function automatic ref_u64 reset_release(bit is_group,int index);
    return is_group ? GROUP_RESET_END : RESET_END;
  endfunction
  function automatic ref_u64 pre_reset_count(bit is_group,int index);
    ref_u64 t;t=reset_begin(is_group,index);
    if(t==0)return 0;
    if(BASIS==0)return t/(STRIDE*1000000);
    return (rank_lt(t)-1)/STRIDE;
  endfunction
  function automatic ref_u64 publication_count(bit is_group,int index);
    if(index==0)begin
      if(BASIS==0)return pre_reset_count(is_group,index)+(END_TICKS-reset_release(is_group,index))/(STRIDE*1000000);
      return pre_reset_count(is_group,index)+(EDGES-rank_lt(reset_release(is_group,index))-1)/STRIDE;
    end
    if(BASIS==0)return END_TICKS/(STRIDE*1000000);
    return (EDGES-1)/STRIDE;
  endfunction
  function automatic ref_window_t interval_counts(bit is_group,int index,ref_u64 left,ref_u64 right);
    ref_window_t v;ref_u64 a,b,lo,hi,n,odd,m;
    m=cardinality(is_group,index);lo=rank_lt(left);hi=rank_lt(right);
    if(lo>ACTIVE_EDGES)lo=ACTIVE_EDGES;if(hi>ACTIVE_EDGES)hi=ACTIVE_EDGES;
    n=hi-lo;odd=(hi+1)/2-(lo+1)/2;
    v.bytes=leaf_weight(is_group,index)*n+3*m*odd;v.events=m*n;
    v.bytes_complete=1;v.events_complete=1;v.reset=0;
    if(affected(is_group,index) && left<=UNKNOWN_TICK && UNKNOWN_TICK<right)begin v.bytes-=4;v.bytes_complete=0;end
    a=(left>RESET_START)?left:RESET_START;b=(right<RESET_END)?right:RESET_END;
    if(affected(is_group,index) && a<b)begin
      lo=rank_lt(a);hi=rank_lt(b);v.bytes-=hi-lo+3*((hi+1)/2-(lo+1)/2);v.events-=hi-lo;v.reset=is_group;
    end
    return v;
  endfunction
  function automatic ref_window_t reference_window(ref_u64 seq,bit is_group,int index);
    ref_window_t v;ref_u64 rank,origin,anchor,left,right,lc,rc,cc;bit after_reset,full;
    after_reset=index==0 && seq>pre_reset_count(is_group,index);
    rank=after_reset ? seq-pre_reset_count(is_group,index) : seq;origin=after_reset ? reset_release(is_group,index) : 0;
    lc=0;rc=0;cc=0;
    if(BASIS==0)begin
      right=origin+rank*STRIDE*1000000;left=(right-origin>=WIDTH*1000000)?right-WIDTH*1000000:origin;
      full=right-origin>=WIDTH*1000000;
    end else begin
      anchor=rank_lt(origin)+1;rc=anchor+rank*STRIDE;lc=(rc-anchor>=WIDTH)?rc-WIDTH:anchor;
      left=clock_tick(lc);right=clock_tick(rc);cc=rc-lc;full=cc==WIDTH;
    end
    v=interval_counts(is_group,index,left,right);v.seq=seq;v.epoch=after_reset;v.left=bw_mon_pkg::measurement_start_ticks+left;v.right=bw_mon_pkg::measurement_start_ticks+right;
    v.left_cycle=lc;v.right_cycle=rc;v.coverage_ticks=right-left;v.coverage_cycles=cc;v.full=full;v.warmup=!full;
    v.denominator_valid=right>left;v.window_valid=full && v.bytes_complete && v.denominator_valid;
    v.gbps=v.denominator_valid ? real'(v.bytes)*1000000.0/real'(right-left) : 0;
    v.bpc=(cc!=0)?real'(v.bytes)/real'(cc):0;return v;
  endfunction
  function automatic ref_raw_t reference_raw(ref_u64 edge_index,bit is_group,int index);
    ref_raw_t r;ref_window_t v,total;ref_u64 tick,left;bit epoch;
    tick=clock_tick(edge_index);epoch=index==0 && tick>=reset_begin(is_group,index);left=epoch ? reset_release(is_group,index) : 0;
    v=interval_counts(is_group,index,tick,tick+1);
    if(epoch && tick<left)begin total.bytes=0;total.events=0;end
    else total=interval_counts(is_group,index,left,tick+1);
    r.seq=edge_index;r.epoch=epoch;r.tick=bw_mon_pkg::measurement_start_ticks+tick;r.edge_index=edge_index;r.byte_inc=v.bytes;r.event_inc=v.events;
    r.bytes_complete=v.bytes_complete;r.events_complete=v.events_complete;
    r.reset_points=affected(is_group,index) && RESET_START<=tick && tick<RESET_END;
    r.total_bytes=total.bytes;r.total_events=total.events;
    r.source_epoch=!is_group && index==0 && tick>=RESET_START;return r;
  endfunction
'''


RESOURCE = r'''
  ref_u64 history_peak=0,clock_peak=0,episode_pending_peak=0,phase_pending_peak=0,frame_peak=0,control_peak=0;
  ref_u64 pending_frames_peak=0,pending_controls_peak=0,pending_timers_peak=0,confirmed_phases=0;
  task automatic observe_resources();
    ref_u64 n;
    if(mon.core.history.size()>history_peak)history_peak=mon.core.history.size();
    if(mon.core.clock_runs.size()>clock_peak)clock_peak=mon.core.clock_runs.size();
    n=0;foreach(mon.core.episode_pending_samples[i])n+=mon.core.episode_pending_samples[i].count;
    if(n>episode_pending_peak)episode_pending_peak=n;
    n=0;foreach(mon.core.phase_pending_samples[i])n+=mon.core.phase_pending_samples[i].count;
    if(n>phase_pending_peak)phase_pending_peak=n;
    if(retained_frame_count(mon.transport_source)>frame_peak)frame_peak=retained_frame_count(mon.transport_source);
    if(retained_control_count(mon.transport_source)>control_peak)control_peak=retained_control_count(mon.transport_source);
    if(mon.core.pending_frames.size()>pending_frames_peak)pending_frames_peak=mon.core.pending_frames.size();
    if(mon.core.pending_member_controls.size()>pending_controls_peak)pending_controls_peak=mon.core.pending_member_controls.size();
    if(mon.core.pending_timers.size()>pending_timers_peak)pending_timers_peak=mon.core.pending_timers.size();
    if(mon.phase_active && mon.phase_confirmation_ticks!=0)confirmed_phases=1;
  endtask
  always @(mon.accepted_record_seq or mon.result_seq or mon.raw_record or mon.raw_control or mon.phase_result_seq)
    if(monitor_ready)observe_resources();
  always @(observation_end)if(observation_end)begin
    observe_resources();
    if(confirmed_phases==0)$fatal(1,"TOPOLOGY_NO_CONFIRMED_PHASE scope=%s",mon.scope_id);
    $fdisplay(resource_fd,"@KIND@,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
      scope_index,history_peak,clock_peak,episode_pending_peak,phase_pending_peak,frame_peak,control_peak,
      pending_frames_peak,pending_controls_peak,pending_timers_peak,
      mon.core.history.size(),mon.core.clock_runs.size(),mon.core.episode_pending_samples.size(),mon.core.phase_pending_samples.size(),
      retained_frame_count(mon.transport_source),retained_control_count(mon.transport_source));
    resources_done++;
  end
'''


def replace_once(text, old, new):
    if text.count(old)!=1:
        raise ValueError('revised fixture template drift: '+old)
    return text.replace(old,new)


def generate(s,out):
    legacy_generate(s,out)
    p=out/'input_pkg.sv';text=p.read_text()
    text=text.replace('  int actual_fd=0,completed_scopes=0;', '  int actual_fd=0,resource_fd=0,edge_fd=0,completed_scopes=0,resources_done=0;\n  ref_u64 input_edge=0;')
    constants=dict(ACTIVE_EDGES=s.active_edges,UNKNOWN_EDGE=s.unknown_edge,GROUP_RESET_START=s.group_reset_start,GROUP_RESET_END=s.group_reset_end,
                   PAUSE_START=s.pause_start,PAUSE_END=s.pause_end)
    text=text.replace('  int variant=0;', ''.join("  localparam ref_u64 {}=64'd{};\n".format(k,v) for k,v in constants.items())+'  int variant=0;')
    weight='  function automatic ref_u64 leaf_weight(bit is_group,int index);\n    if(!is_group)return index+1;\n    case(index)\n'
    weight+=''.join('      {}:return {};\n'.format(g,s.weights[g]) for g in s.groups)
    weight+='      default:$fatal(1,"TOPOLOGY_REFERENCE_WEIGHT");\n    endcase\n    return 0;\n  endfunction\n'
    start=text.index('  function automatic ref_u64 pre_reset_count();')
    end=text.index('  function automatic bit close_real',start)
    text=text[:start]+weight+REFERENCE+text[end:]
    p.write_text(text)
    p=out/'checker.sv';text=p.read_text()
    text=text.replace('reference_raw(records,m,hit,own)','reference_raw(records,is_group,scope_index)')
    text=text.replace('reference_window(windows,m,hit,own)','reference_window(windows,is_group,scope_index)')
    text=text.replace('publication_count(own)','publication_count(is_group,scope_index)')
    # A delayed collector may publish its next raw frame in the same physical
    # slot as the previous acceptance. Pair public publications with receipts
    # by sequence; reading the latest publication at receipt time loses data.
    text=text.replace('raw_record.', 'accepted_frame.')
    text=text.replace('  ref_window_t window_snapshot;ref_raw_t raw_snapshot;', '''  ref_window_t window_snapshot;ref_raw_t raw_snapshot;
  bw_record_t published_frames[ref_u64],accepted_frame;
  ref_u64 publications=0;
  always @(raw_record)if(monitor_ready && raw_record.record_seq!=0)begin
    if(raw_record.record_seq!=publications+1)$fatal(1,"TOPOLOGY_RAW_PUBLICATION_SEQUENCE");
    publications++;published_frames[raw_record.record_seq]=raw_record;
  end''')
    text=text.replace('ref_raw_t e;records++;e=reference_raw', '''ref_raw_t e;records++;
    if(!published_frames.exists(records))$fatal(1,"TOPOLOGY_MISSING_PUBLICATION_RECEIPT");
    accepted_frame=published_frames[records];published_frames.delete(records);e=reference_raw''')
    p.write_text(text)
    p=out/'tb_bw_scale.sv';text=p.read_text()
    text=text.replace('logic [63:0] size_bytes=64;', 'logic [63:0] size_bytes;')
    start=text.index('  initial begin\n    wait(monitor_ready);\n    if(scope_index==0 && variant==1)')
    end=text.index('  initial begin',start+5)
    text=text[:start]+'''  always_comb begin
    size_bytes=scope_index+1+3*(input_edge%2);
    if(scope_index==0 && input_edge==UNKNOWN_EDGE)size_bytes='x;
  end
'''+text[end:]
    text=text.replace(".valid(1'b1),.ready(1'b1),.flitv(1'b1),.lcrdv(1'b1),.size_bytes(size_bytes),.size_known(1'b1)",
                      ".valid(input_edge<=ACTIVE_EDGES),.ready(1'b1),.flitv(input_edge<=ACTIVE_EDGES),.lcrdv(input_edge<=ACTIVE_EDGES),.size_bytes(size_bytes),.size_known(1'b1)")
    text=text.replace('.DYNAMIC(p%2==0)', '.DYNAMIC(1)')
    text=text.replace('  bit local_done=0;\n  bw_group_mon', '''  bit local_done=0;logic stats_reset_n=1;
  initial begin
    wait(monitor_ready);
    if(scope_index==0)begin #GROUP_RESET_START;stats_reset_n=0;#(GROUP_RESET_END-GROUP_RESET_START);stats_reset_n=1;end
  end
  bw_group_mon''')
    text=text.replace("mon(.clk(clk),.reset_n(1'b1));", 'mon(.clk(clk),.reset_n(stats_reset_n));')
    text=text.replace('    for(int m=0;m<mon.direct_member_count;m++)', '''    for(int m=0;m<mon.direct_member_count;m++)
      $fdisplay(edge_fd,"%0d,%0d,%s,%s",scope_index,m,source_kind_name(member_source(mon.group_handle,m)),source_name(member_source(mon.group_handle,m)));
    for(int m=0;m<mon.direct_member_count;m++)''')
    # Observe only public acceptance receipts and consumer positions. This also
    # fails if the automatic collector acknowledges a published but unaccepted frame.
    group_observer=r'''
  always @(mon.raw_record or mon.accepted_record_seq)if(monitor_ready && mon.direct_member_count!=0)begin
    for(int i=0;i<mon.direct_member_count;i++)
      if(acknowledged_frame_seq(mon.group_handle,i)>mon.accepted_record_seq)
        $fatal(1,"TOPOLOGY_ACK_BEFORE_ACCEPT scope=%s",mon.scope_id);
  end
'''
    text=replace_once(text,'endmodule\nmodule bw_scale_group',RESOURCE.replace('@KIND@','point')+'endmodule\nmodule bw_scale_group')
    text=replace_once(text,'endmodule\nmodule tb_bw_scale',group_observer+RESOURCE.replace('@KIND@','group')+'endmodule\nmodule tb_bw_scale')
    text=text.replace('logic clk=0;bit deadline=0;string variant_name,actual_path;', 'logic clk=0;bit deadline=0;string variant_name,actual_path;\n  bw_test_consumer_gate slow_gate;')
    text=text.replace('    $fdisplay(actual_fd,"kind,', '    resource_fd=$fopen({actual_path,".resources.csv"},"w");\n    $fdisplay(resource_fd,"kind,index,history_peak,clock_peak,episode_pending_peak,phase_pending_peak,frame_peak,control_peak,pending_frames_peak,pending_controls_peak,pending_timers_peak,history_final,clock_final,episode_pending_final,phase_pending_final,frames_final,controls_final");\n    $fdisplay(actual_fd,"kind,')
    text=text.replace('    $display("SCALE_RUN_START ', '    $display("ACCEPTANCE_READY");$fflush();\n    $display("SCALE_RUN_START ')
    text=text.replace('    resource_fd=$fopen', '    edge_fd=$fopen({actual_path,".edges.csv"},"w");\n    $fdisplay(edge_fd,"group,member,kind,source");\n    resource_fd=$fopen')
    text=text.replace('    $fclose(actual_fd);', '    $fclose(actual_fd);$fclose(resource_fd);$fclose(edge_fd);')
    text=text.replace('    $fclose(actual_fd);', '    foreach(bw_test_storage_peak[resource])$display("TOPOLOGY_STORAGE resource=%s queue_high_water=%0d",resource,bw_test_storage_peak[resource]);\n    $fclose(actual_fd);')
    text=text.replace('wait(completed_scopes==SCOPES);', 'wait(completed_scopes==SCOPES && resources_done==SCOPES);')
    text=text.replace('      #(measurement_start_ticks+clock_tick(k)-$time);clk=1;#1;clk=0;', '      #(measurement_start_ticks+clock_tick(k)-$time-1);input_edge=k;#1;clk=1;#1;clk=0;')
    text=text.replace('input_edge=k;#1;clk=1;#1;clk=0;', 'input_edge=k;#1;clk=1;#1;clk=0;\n      if(k%64==0)begin $display("TOPOLOGY_PROGRESS edge=%0d ticks=%0d",k,$time);$fflush();end')
    pause=r'''
  initial begin : delayed_actual_consumer
    bw_control_frame_t pending;
    wait(monitor_ready);slow_gate=bw_test_gate_for("scale.g8");
    #PAUSE_START;slow_gate.paused=1;
    #(measurement_start_ticks+101500000-$time);
    if(groups[0].slot.mon.accepted_record_seq!=203 || groups[1].slot.mon.accepted_record_seq!=203 ||
       groups[8].slot.mon.accepted_record_seq!=198 ||
       acknowledged_frame_seq(groups[1].slot.mon.group_handle,0)!=203 ||
       acknowledged_frame_seq(groups[8].slot.mon.group_handle,0)!=198 ||
       retained_frame_count(groups[0].slot.mon.transport_source)!=5 ||
       retained_control_count(groups[0].slot.mon.transport_source)!=2 ||
       !peek_member_control(groups[8].slot.mon.group_handle,0,pending) ||
       pending.value.timestamp_ticks!=measurement_start_ticks+RESET_START ||
       groups[0].slot.mon.core.history.size()<4)
      $fatal(1,"TOPOLOGY_DELAY_RETENTION");
    if(BASIS==0 && groups[8].slot.mon.window_end_ticks>measurement_start_ticks+99000000)
      $fatal(1,"TOPOLOGY_DELAY_TIMER_WATERMARK");
    if(BASIS==1 && groups[8].slot.mon.window_end_cycle>198)
      $fatal(1,"TOPOLOGY_DELAY_CYCLE_WATERMARK");
    $display("TOPOLOGY_BACKLOG source=scale.g0 consumers=16 fast_ack=203 slow_ack=198 retained_frames=5 retained_controls=2 history_segments=%0d",groups[0].slot.mon.core.history.size());
    #(measurement_start_ticks+PAUSE_END-$time);slow_gate.paused=0;
    #1;
    if(groups[8].slot.mon.accepted_record_seq!=204 ||
       acknowledged_frame_seq(groups[8].slot.mon.group_handle,0)!=204 ||
       retained_frame_count(groups[0].slot.mon.transport_source)!=0 ||
       retained_control_count(groups[0].slot.mon.transport_source)!=0)
      $fatal(1,"TOPOLOGY_DELAY_RELEASE");
    $display("TOPOLOGY_INTERACTION_PASS original_time=1 all_consumers_released=1 basis=%0d",BASIS);$fflush();
  end
'''
    text=text.replace('  always @(deadline or completed_scopes)',pause+'  always @(deadline or completed_scopes)')
    p.write_text(text)


def verify(s,out):
    passed,evidence=verify_streams(s,out)
    diffs=json.loads((out/'diffs.json').read_text())
    log=(out/'simulation.log').read_text()
    rows=list(csv.DictReader((out/'actual.csv.resources.csv').open())) if (out/'actual.csv.resources.csv').exists() else []
    observed={(r['kind'],int(r['index'])):r for r in rows}
    if len(rows)!=s.points+len(s.groups) or set(observed)!=set(s.scopes()):
        diffs.append(dict(error='resource_scope_completeness'))
    edge_path=out/'actual.csv.edges.csv'
    actual_edges=list(csv.DictReader(edge_path.open())) if edge_path.exists() else []
    expected_edges={(g,m):(kind,s.identity(kind,index)) for g,members in s.groups.items()
                    for m,(kind,index) in enumerate(members)}
    observed_edges={}
    for edge in actual_edges:
        key=(int(edge['group']),int(edge['member']))
        if key in observed_edges:
            diffs.append(dict(error='duplicate_direct_edge',key=key))
        observed_edges[key]=(edge['kind'],edge['source'])
    if observed_edges!=expected_edges:
        diffs.append(dict(error='direct_edge_identity',expected_count=len(expected_edges),observed_count=len(actual_edges),
                          mismatches=[dict(key=k,expected=v,actual=observed_edges.get(k))
                                      for k,v in expected_edges.items() if observed_edges.get(k)!=v][:20]))
    totals={field:0 for field in rows[0] if field not in ('kind','index')} if rows else {}
    for key,row in observed.items():
        for field in totals:
            totals[field]+=int(row[field])
        if int(row['history_peak'])<4:
            diffs.append(dict(error='actual_history_did_not_fragment',scope=key))
        for field in ('frames_final','controls_final','episode_pending_final','phase_pending_final'):
            if int(row[field])!=0:
                diffs.append(dict(error='state_not_released',scope=key,field=field,value=row[field]))
    if log.count('TOPOLOGY_INTERACTION_PASS ')!=1 or log.count('TOPOLOGY_BACKLOG ')!=1:
        diffs.append(dict(error='missing_shared_interaction'))
    peaks={name:int(value) for name,value in re.findall(r'^TOPOLOGY_STORAGE resource=(\S+) queue_high_water=(\d+)$',log,re.M)}
    for resource,minimum in [('registry.source',s.points+len(s.groups)),('registry.groups',len(s.groups)),
                             ('registry.points',s.points),('core.controls',1),('core.frames',1),
                             ('transport.frames',6),('transport.controls',2),('history.events',4)]:
        if peaks.get(resource,0)<minimum:
            diffs.append(dict(error='storage_growth_high_water',resource=resource,minimum=minimum,actual=peaks.get(resource)))
    evidence.update(resource_scopes=len(rows),state_high_water_sums=totals,
                    direct_edges_checked=len(actual_edges),
                    high_water_semantics='sum of per-scope sampled maxima; not a simultaneous global peak',
                    storage_queue_high_water_by_resource=peaks,
                    shared_interaction='M4/H6 subgroup0 with16parents,5frames+2controls retained while fast consumers advance',
                    difference_count=len(diffs))
    save(out/'diffs.json',diffs);save(out/'verification.json',evidence)
    return not diffs,evidence
