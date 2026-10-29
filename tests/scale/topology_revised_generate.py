"""Public topology fixture. Reference depends on fixed input weights/leaf sets only."""
import csv
import json
import re
from collections import Counter
from generate import generate as legacy_generate
from run import verify as verify_streams, save
from time_origin import measurement_start
from topology_revised import interaction_diffs


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
    fast=s.fast_consumers
    if len(fast)!=15 or s.slow_consumer in fast:
        raise ValueError('interaction expects the shared subgroup to have exactly 16 direct consumers')
    constants=dict(ACTIVE_EDGES=s.active_edges,UNKNOWN_EDGE=s.unknown_edge,GROUP_RESET_START=s.group_reset_start,GROUP_RESET_END=s.group_reset_end,
                   GATE_EDGE=s.gate_edge,RELEASE_TICK=s.release_tick,CONTROL_HOLD_TICK=s.control_hold_tick,
                   SLOW_CONSUMER=s.slow_consumer,
                   TIMER_BOUND_NS=s.slow_timer_bound_ns,CYCLE_WATERMARK=s.slow_consumer_ack,
                   SLOW_ACK=s.slow_consumer_ack,HELD_FRAMES=s.held_frame_count,HELD_CONTROLS=s.held_control_count)
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
    if s.cancel_interaction:
        # A cancelled consumer completes with typed terminal evidence but no
        # public stream row: its counters legitimately stop at the failure.
        text=replace_once(text,'windows==publication_count(is_group,scope_index) && records==EDGES)begin',
                          '(scope_disabled(is_group?BW_GROUP:BW_POINT,scope_id) ||\n        (windows==publication_count(is_group,scope_index) && records==EDGES)))begin')
        text=replace_once(text,'      done=1;\n      $fdisplay(actual_fd,"',
                          '      done=1;\n      if(!scope_disabled(is_group?BW_GROUP:BW_POINT,scope_id))\n      $fdisplay(actual_fd,"')
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
    # Arm the M4/H6 slow consumer inside the hold edge's own slot, one
    # representable tick before its sampling edge; the durable resume
    # continuation keeps the hold legal without any positive-time pause.
    gate_arm=('      if(k==GATE_EDGE)begin\n'
              '        slow_gate.resume_after_seq=GATE_EDGE;\n'
              '        slow_gate.paused=1;\n'
              '      end\n')
    control_arm=('''  initial begin : control_hold_arm
    wait(monitor_ready);
    #(measurement_start_ticks+CONTROL_HOLD_TICK-1-$time);
    slow_gate.resume_after_seq=SLOW_ACK;
'''
                 + ''.join('    slow_gate.resume_after_groups.push_back("{}");\n'.format(s.group_id(g))
                           for g in fast)
                 + '    slow_gate.paused=1;\n'
                   '  end\n')
    fast_wait='\n    '.join('wait(group_batches["%s"].acked>=%d);'%(s.group_id(g),s.gate_edge)
                           for g in s.fast_consumers)
    cancel_section=('''
    runtime_scope_error(BW_GROUP,"{slow_id}","TEST_CONSUMER_FAILURE",
      "full-topology same-time consumer cancellation with {frames} unread frames");
    if(!scope_disabled(BW_GROUP,"{slow_id}") ||
       retained_frame_count(groups[{source}].slot.mon.transport_source)!=0 ||
       retained_control_count(groups[{source}].slot.mon.transport_source)!=0 ||
       acknowledged_frame_seq(groups[{slow}].slot.mon.group_handle,0)!=SLOW_ACK)
      $fatal(1,"TOPOLOGY_CANCEL_RESPONSIBILITY ticks=%0d",$time);
    $display("TOPOLOGY_CANCEL_RELEASE root={slow_id} frames=0 controls=0 slow_ack=%0d healthy_source={source_id}",SLOW_ACK);
    wait(groups[{source}].slot.mon.accepted_record_seq>GATE_EDGE);
    if(scope_disabled(BW_GROUP,"{source_id}") || scope_disabled(BW_GROUP,"{fast0_id}"))
      $fatal(1,"TOPOLOGY_CANCEL_HEALTHY_CHAIN");
    $display("TOPOLOGY_CANCEL_HEALTHY source={source_id} accepted=%0d basis=%0d",
      groups[{source}].slot.mon.accepted_record_seq,BASIS);
    $display("TOPOLOGY_CANCEL_PASS cancelled_consumers=1 released=1 basis=%0d",BASIS);
'''.format(slow=s.slow_consumer, slow_id=s.group_id(s.slow_consumer), source=s.interaction_source,
           source_id=s.group_id(s.interaction_source), fast0_id=s.group_id(s.fast_consumers[0]),
           frames=s.held_frame_count)
             if s.cancel_interaction else '')
    resume_section=('''
    wait(group_batches["{slow_id}"].acked>=GATE_EDGE);
    if($time!=measurement_start_ticks+RELEASE_TICK)$fatal(1,"TOPOLOGY_RELEASE_NOT_ORIGINAL_TIME ticks=%0d",$time);
    if(groups[{slow}].slot.mon.accepted_record_seq!=GATE_EDGE ||
       acknowledged_frame_seq(groups[{slow}].slot.mon.group_handle,0)!=GATE_EDGE ||
       retained_frame_count(groups[{source}].slot.mon.transport_source)!=0 ||
       retained_control_count(groups[{source}].slot.mon.transport_source)!=0)
      $fatal(1,"TOPOLOGY_SAME_TIME_RELEASE ticks=%0d",$time);
    $display("TOPOLOGY_INTERACTION_PASS original_time=1 all_consumers_released=1 basis=%0d",BASIS);
'''.format(slow=s.slow_consumer, slow_id=s.group_id(s.slow_consumer), source=s.interaction_source)
             if not s.cancel_interaction else '')
    interaction=('''
  initial slow_gate=bw_test_gate_for("{slow_id}");
{control_arm}  task automatic observe_interaction();
    bw_control_frame_t pending;
    bw_u64_t seen_controls;
    wait(monitor_ready);
    // Event one: the member reset release control is forwarded in its own
    // stamp slot; the held consumer keeps it unread in that original slot.
    // Waits use variables (function calls have no wait sensitivity).
    #(measurement_start_ticks+CONTROL_HOLD_TICK-1-$time);
    seen_controls=groups[{source}].slot.mon.control_result_seq;
    wait(groups[{source}].slot.mon.control_result_seq!=seen_controls);
    if(retained_control_count(groups[{source}].slot.mon.transport_source)!={controls} ||
       retained_frame_count(groups[{source}].slot.mon.transport_source)!=0 ||
       registered_sources[groups[{source}].slot.mon.transport_source].control_acks[groups[{slow}].slot.mon.group_handle]
         ==registered_sources[groups[{source}].slot.mon.transport_source].last_control_seq ||
       !peek_member_control(groups[{slow}].slot.mon.group_handle,0,pending) ||
       pending.value.timestamp_ticks!=measurement_start_ticks+CONTROL_HOLD_TICK)
      $fatal(1,"TOPOLOGY_CONTROL_HOLD ticks=%0d controls=%0d",$time,
        retained_control_count(groups[{source}].slot.mon.transport_source));
    $display("TOPOLOGY_BACKLOG_CONTROL source={source_id} consumers=16 retained_controls=%0d retained_frames=0",
      retained_control_count(groups[{source}].slot.mon.transport_source));
    wait(registered_sources[groups[{source}].slot.mon.transport_source].control_acks[groups[{slow}].slot.mon.group_handle]
         ==registered_sources[groups[{source}].slot.mon.transport_source].last_control_seq);
    if($time!=measurement_start_ticks+CONTROL_HOLD_TICK || retained_control_count(groups[{source}].slot.mon.transport_source)!=0)
      $fatal(1,"TOPOLOGY_CONTROL_RELEASE ticks=%0d",$time);
    $display("TOPOLOGY_CONTROL_RELEASE original_time=1 released_controls=1");
    // Event two: the gate edge slot holds the slot's own frame unread while
    // the fifteen fast peers already published, accepted and acked it.
    {fast_wait}
    if(groups[{slow}].slot.mon.accepted_record_seq!=SLOW_ACK ||
       acknowledged_frame_seq(groups[{slow}].slot.mon.group_handle,0)!=SLOW_ACK ||
       groups[{source}].slot.mon.accepted_record_seq!=GATE_EDGE ||
       retained_frame_count(groups[{source}].slot.mon.transport_source)!=HELD_FRAMES ||
       retained_control_count(groups[{source}].slot.mon.transport_source)!=0 ||
       groups[{source}].slot.mon.core.history.size()<4)
      $fatal(1,"TOPOLOGY_SAME_TIME_HOLD slow=%0d/%0d source=%0d frames=%0d/%0d",
        groups[{slow}].slot.mon.accepted_record_seq,SLOW_ACK,groups[{source}].slot.mon.accepted_record_seq,
        retained_frame_count(groups[{source}].slot.mon.transport_source),HELD_FRAMES);
    if(BASIS==0 && groups[{slow}].slot.mon.window_end_ticks>measurement_start_ticks+TIMER_BOUND_NS*1000000)
      $fatal(1,"TOPOLOGY_DELAY_TIMER_WATERMARK");
    if(BASIS==1 && groups[{slow}].slot.mon.window_end_cycle>{slow_cycle_watermark})
      $fatal(1,"TOPOLOGY_DELAY_CYCLE_WATERMARK");
    $display("TOPOLOGY_BACKLOG source={source_id} consumers=16 fast_ack=%0d slow_ack=%0d retained_frames=%0d retained_controls=0 history_segments=%0d",
      GATE_EDGE,SLOW_ACK,HELD_FRAMES,groups[{source}].slot.mon.core.history.size());
{cancel}{resume}    $fflush();
  endtask
  initial begin : same_time_interaction
    observe_interaction();
  end
'''.format(slow=s.slow_consumer, source=s.interaction_source, controls=s.held_control_count,
           slow_id=s.group_id(s.slow_consumer), source_id=s.group_id(s.interaction_source),
           control_arm=control_arm, fast_wait=fast_wait, cancel=cancel_section,
           resume=resume_section, slow_cycle_watermark=s.slow_consumer_ack))
    text=text.replace('      #(measurement_start_ticks+clock_tick(k)-$time);clk=1;#1;clk=0;',
                      '      #(measurement_start_ticks+clock_tick(k)-$time-1);input_edge=k;\n'+gate_arm+'      #1;clk=1;#1;clk=0;')
    text=text.replace('      #1;clk=1;#1;clk=0;',
                      '      #1;clk=1;#1;clk=0;\n      if(k%64==0)begin $display("TOPOLOGY_PROGRESS edge=%0d ticks=%0d",k,$time);$fflush();end')
    text=text.replace('  always @(deadline or completed_scopes)',interaction+'  always @(deadline or completed_scopes)')
    if s.cancel_interaction:
        # The failed consumer never completes its input ledger; its terminal
        # evidence is the DISABLED state and its public CSV row is absent. Its
        # registered direct edges still exist and are still exported.
        text=replace_once(text,'always @(observation_end)if(observation_end)begin\n    if(mon.direct_member_count',
                          'always @(observation_end)if(observation_end)begin\n'
                          '    if(!scope_disabled(BW_GROUP,mon.scope_id))begin\n    if(mon.direct_member_count')
        text=replace_once(text,'      $fatal(1,"SCALE_GROUP_MEMBERS_CONTROLS scope=%s",mon.scope_id);\n'
                          '    for(int m=0;m<mon.direct_member_count;m++)\n'
                          '      $fdisplay(edge_fd,',
                          '      $fatal(1,"SCALE_GROUP_MEMBERS_CONTROLS scope=%s",mon.scope_id);\n'
                          '    end\n'
                          '    for(int m=0;m<mon.direct_member_count;m++)\n'
                          '      $fdisplay(edge_fd,')
        text=replace_once(text,'    for(int m=0;m<mon.direct_member_count;m++)\n'
                          '      if(acknowledged_frame_seq(mon.group_handle,m)!=EDGES)',
                          '    if(!scope_disabled(BW_GROUP,mon.scope_id))begin\n'
                          '    for(int m=0;m<mon.direct_member_count;m++)\n'
                          '      if(acknowledged_frame_seq(mon.group_handle,m)!=EDGES)')
        text=replace_once(text,'if(acknowledged_frame_seq(mon.group_handle,m)!=EDGES)$fatal(1,"SCALE_ACK_MISMATCH scope=%s member=%0d",mon.scope_id,m);\n    local_done=1;',
                          'if(acknowledged_frame_seq(mon.group_handle,m)!=EDGES)$fatal(1,"SCALE_ACK_MISMATCH scope=%s member=%0d",mon.scope_id,m);\n    end\n    local_done=1;')
    p.write_text(text)


def _shared_stream_diffs(s,out,log):
    """Topology-shape checks shared by every profile: per-scope classified
    state high-water/release, the independent direct-edge identity audit and
    the real growth-request storage peaks."""
    diffs=[]
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
    cancelled={( 'group',s.slow_consumer)} if s.cancel_interaction else set()
    totals={field:0 for field in rows[0] if field not in ('kind','index')} if rows else {}
    for key,row in observed.items():
        for field in totals:
            totals[field]+=int(row[field])
        if int(row['history_peak'])<4:
            diffs.append(dict(error='actual_history_did_not_fragment',scope=key))
        frozen_analysis=key in cancelled
        for field in ('frames_final','controls_final','episode_pending_final','phase_pending_final'):
            # A cancelled scope keeps its frozen pre-failure analysis evidence
            # (D8 forbids reviving it); its transport responsibilities, like
            # every other scope's, must still be fully released.
            if int(row[field])!=0 and not (frozen_analysis and field.endswith('pending_final')):
                diffs.append(dict(error='state_not_released',scope=key,field=field,value=row[field]))
    peaks={name:int(value) for name,value in re.findall(r'^TOPOLOGY_STORAGE resource=(\S+) queue_high_water=(\d+)$',log,re.M)}
    for resource,minimum in [('registry.source',s.points+len(s.groups)),('registry.groups',len(s.groups)),
                             ('registry.points',s.points),('core.controls',1),('core.frames',1),
                             ('transport.frames',s.held_frame_count),('transport.controls',s.held_control_count),
                             ('history.events',4)]:
        if peaks.get(resource,0)<minimum:
            diffs.append(dict(error='storage_growth_high_water',resource=resource,minimum=minimum,actual=peaks.get(resource)))
    # The member-reset window splits the first platform of every covering
    # non-owner scope: exactly one WARNING/OBSERVATION_INCOMPLETE row each.
    default_rows=[dict(re.findall(r'(\w+)=([^\s]+)',l)) for l in log.splitlines()
                  if l.startswith('BW_DEFAULT_CHECK ')]
    interrupted=s.interrupted_platform_scopes()
    seen_warning={r.get('scope') for r in default_rows
                  if r.get('conclusion')=='WARNING' and r.get('reason')=='OBSERVATION_INCOMPLETE'}
    if seen_warning!=interrupted:
        diffs.append(dict(error='interrupted_platform_rows',expected=len(interrupted),
                          observed=len(seen_warning),unexpected=sorted(seen_warning-interrupted)[:8],
                          missing=sorted(interrupted-seen_warning)[:8]))
    evidence=dict(resource_scopes=len(rows),state_high_water_sums=totals,
                  direct_edges_checked=len(actual_edges),
                  high_water_semantics='sum of per-scope sampled maxima; not a simultaneous global peak',
                  storage_queue_high_water_by_resource=peaks,
                  interrupted_platform_scopes=len(interrupted))
    return diffs,evidence


def verify(s,out):
    if s.cancel_interaction:
        return verify_cancel(s,out)
    passed,evidence=verify_streams(s,out)
    diffs=json.loads((out/'diffs.json').read_text())
    log=(out/'simulation.log').read_text()
    shared,shared_evidence=_shared_stream_diffs(s,out,log)
    diffs+=shared
    diffs+=interaction_diffs(log,s)
    evidence.update(shared_evidence,
                    shared_interaction='M4/H6 same-slot hold of one of16 consumers; %d frames+%d controls retained at original ticks, released inside the resume edge slot'
                    %(s.held_frame_count,s.held_control_count),
                    difference_count=len(diffs))
    save(out/'diffs.json',diffs);save(out/'verification.json',evidence)
    return not diffs,evidence


def verify_cancel(s,out):
    """H6 cancellation leg: the held consumer fails, its responsibility is
    cancelled and unread data released while every healthy scope still
    completes the full frozen short sequence."""
    from scenario import CSV_FIELDS
    from fractions import Fraction as F
    diffs=[]
    log=(out/'simulation.log').read_text()
    lines=log.splitlines()
    try:
        origin=measurement_start(log)
    except ValueError as error:
        diffs.append(dict(error='measurement_start',detail=str(error)));origin=0
    expected={(r['kind'],int(r['index'])):r for r in csv.DictReader((out/'expected.csv').open())}
    actual={}
    for row in csv.DictReader((out/'actual.csv').open()):
        key=(row['kind'],int(row['index']))
        if key in actual:diffs.append(dict(error='duplicate_scope',key=key))
        actual[key]=row
    cancelled={('group',s.slow_consumer)}
    if set(actual)!=set(expected)-cancelled:
        diffs.append(dict(error='cancel_scope_completeness',expected=len(expected)-len(cancelled),actual=len(actual)))
    for key in sorted(set(expected)&set(actual)):
        for field in CSV_FIELDS:
            a,e=actual[key].get(field),expected[key][field]
            if field in ('window_left','window_right','raw_tick'):e=str(int(e)+origin)
            if field in ('window_gbps','window_bpc'):
                try:good=abs(F(a)-F(e))<=F(1,10**9)+F(1,10**12)*abs(F(e))
                except (ValueError,TypeError,ZeroDivisionError):good=False
            else:good=a==e
            if not good:diffs.append(dict(key=key,field=field,expected=e,actual=a))
    # Episodes, default rows and metrics of healthy scopes keep the frozen
    # independent expectations; the failed scope settles from frozen evidence.
    def keyvalues(line):return dict(re.findall(r'(\w+)=([^\s]+)',line))
    episodes=[keyvalues(l) for l in lines if l.startswith('BW_EPISODE ')]
    default_checks=[keyvalues(l) for l in lines if l.startswith('BW_DEFAULT_CHECK ')]
    checks=[keyvalues(l) for l in lines if l.startswith('BW_CHECK ')]
    byid={s.identity(k,i):(k,i) for k,i in s.scopes()}
    slow_id=s.group_id(s.slow_consumer)
    seen={}
    for e in episodes:
        sid=e.get('scope');seq=int(e.get('result_seq','0'))
        if sid not in byid:diffs.append(dict(error='unknown_episode_scope',record=e));continue
        seen.setdefault(sid,[]).append(e)
        if sid==slow_id:continue
        kind,index=byid[sid]
        references=s.expected_episodes(kind,index)
        if not 1<=seq<=len(references):
            diffs.append(dict(error='extra_episode',scope=sid,seq=seq));continue
        if seq!=len(seen[sid]):diffs.append(dict(error='episode_sequence',scope=sid,expected=len(seen[sid]),actual=seq))
    for sid,(kind,index) in byid.items():
        if sid==slow_id:continue
        n=len(s.expected_episodes(kind,index))
        if len(seen.get(sid,[]))!=n:diffs.append(dict(error='episode_count',scope=sid,expected=n,actual=len(seen.get(sid,[]))))
        rows=[d for d in default_checks if d.get('scope')==sid]
        if len(rows)!=s.expected_default_rows(kind,index):
            diffs.append(dict(error='default_row_count',scope=sid,
                              expected=s.expected_default_rows(kind,index),actual=len(rows)))
    slow_defaults=[d for d in default_checks if d.get('scope')==slow_id]
    if len(slow_defaults)!=1 or slow_defaults[0].get('conclusion')!='WARNING':
        diffs.append(dict(error='cancel_default_settlement',actual=slow_defaults))
    summaries=[keyvalues(l) for l in lines if l.startswith('BW_SUMMARY ')]
    metrics=Counter(c.get('conclusion') for c in checks)
    default_metrics=Counter(d.get('conclusion') for d in default_checks)
    if len(summaries)!=1:
        diffs.append(dict(error='summary_count',actual=len(summaries)))
    else:
        x=summaries[0];scopes=s.points+len(s.groups)
        if x.get('scopes_done')!=str(scopes) or x.get('scopes_expected')!=str(scopes):
            diffs.append(dict(error='summary_scope_barrier',actual=x))
        combined=metrics+default_metrics
        # The cancelled scope's MONITOR_DISABLED settlement adds one summary
        # warning without a per-metric BW_CHECK row.
        combined['WARNING']=combined['WARNING']+1
        for field,conclusion in [('pass','PASS'),('fail','FAIL'),('warning','WARNING')]:
            if x.get(field)!=str(combined[conclusion]):
                diffs.append(dict(error='summary_counter',field=field,actual=x.get(field),expected=combined[conclusion]))
        want='FAIL' if combined['FAIL'] else 'WARNING' if combined['WARNING'] else 'PASS'
        if x.get('status')!=want:diffs.append(dict(error='summary_status',actual=x.get('status'),expected=want))
    warnings=[keyvalues(l) for l in lines if l.startswith('BW_CORE_WARNING ')]
    if len(warnings)!=1 or warnings[0].get('code')!='TEST_CONSUMER_FAILURE' or warnings[0].get('scope')!=slow_id:
        diffs.append(dict(error='cancel_warning_contract',actual=warnings))
    if any(l.startswith('BW_SCOPE_DISABLED ') for l in lines):
        diffs.append(dict(error='unexpected_ancestor_isolation'))
    terminals=[keyvalues(l) for l in lines if l.startswith('BW_GROUP_TERMINAL ') or l.startswith('BW_POINT_TERMINAL ')]
    disabled=[t for t in terminals if t.get('state')!='NORMAL']
    if len(terminals)!=s.points+len(s.groups) or len(disabled)!=1 or disabled[0].get('scope')!=slow_id or disabled[0].get('state')!='DISABLED':
        diffs.append(dict(error='cancel_terminal_states',terminals=len(terminals),disabled=[t.get('scope') for t in disabled]))
    completed=[l for l in lines if l.startswith('BW_REPORT_COMPLETE ')]
    if len(completed)!=1 or 'integrity=INCOMPLETE' not in completed[0] or 'summary=1' not in completed[0]:
        diffs.append(dict(error='cancel_report_contract',actual=completed))
    if 'SCALE_PASS ' not in log or re.search(r'Fatal:|Error-\[|SCALE_\w*MISMATCH|BW_CFG_WARNING',log):
        diffs.append(dict(error='simulation_completion_or_diagnostic'))
    shared,shared_evidence=_shared_stream_diffs(s,out,log)
    diffs+=shared
    diffs+=interaction_diffs(log,s)
    evidence=dict(measurement_start_ticks=origin,expected_csv_scopes=len(expected)-len(cancelled),
                  observed_csv_scopes=len(actual),cancelled_scope=slow_id,
                  checked_raw=sum(int(r['checked_records']) for r in actual.values()),
                  checked_windows=sum(int(r['checked_windows']) for r in actual.values()),
                  episode_records=len(episodes),default_check_records=len(default_checks),
                  report_conclusions=dict(metrics),default_check_conclusions=dict(default_metrics),
                  cancellation='held consumer failed in the resume slot; responsibility cancelled, unread data released, healthy chain completed the frozen sequence',
                  difference_count=0)
    evidence.update(shared_evidence);evidence['difference_count']=len(diffs)
    save(out/'diffs.json',diffs);save(out/'verification.json',evidence)
    return not diffs,evidence
