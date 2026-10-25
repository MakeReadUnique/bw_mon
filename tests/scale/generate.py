#!/usr/bin/env python3
"""Generate real public-module integration plus online stimulus/leaf-set checks."""
import csv,json
from pathlib import Path
from fractions import Fraction
from scenario import CSV_FIELDS,WINDOW_FIELDS,RAW_FIELDS

PUBLIC={'seq':'result_seq','epoch':'stats_epoch','left':'window_start_ticks','right':'window_end_ticks',
 'left_cycle':'window_start_cycle','right_cycle':'window_end_cycle','coverage_ticks':'coverage_ticks','coverage_cycles':'coverage_cycles',
 'bytes':'window_bytes','events':'window_events','warmup':'window_warmup','full':'window_full','bytes_complete':'bytes_complete',
 'events_complete':'events_complete','denominator_valid':'denominator_valid','window_valid':'window_valid','reset':'member_reset_coverage',
 'gbps':'bandwidth_gbps','bpc':'bytes_per_cycle'}
RAW_PUBLIC={'seq':'accepted_record_seq','epoch':'stats_epoch','tick':'raw_record.timestamp_ticks','edge_index':'raw_record.edge_index',
 'byte_inc':'raw_record.byte_inc','event_inc':'raw_record.event_inc','bytes_complete':'raw_record.bytes_complete',
 'events_complete':'raw_record.events_complete','reset_points':'raw_record.reset_points','total_bytes':'total_bytes','total_events':'total_events','source_epoch':'raw_record.source_epoch'}

def real_text(value):return format(float(value),'.17g') if isinstance(value,Fraction) else value

def generate(s,out):
    out.mkdir(parents=True,exist_ok=True)
    (out/'input.json').write_text(json.dumps(s.manifest(),indent=2,sort_keys=True)+'\n')
    with (out/'expected.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=CSV_FIELDS);w.writeheader()
        for kind,index in s.scopes():w.writerow({k:real_text(v) for k,v in s.final_scope(kind,index).items()})
    config=[]
    for kind,index in s.scopes():
        m,_,_=s.meta(kind,index);rate=128*m
        config += ['[{} {}]'.format(kind,s.identity(kind,index)),
         'e2e_bw_min_gbps='+str(rate),'steady_bw_min_gbps='+str(rate),
         'ramp_time_max_ns=40000','fall_time_max_ns=40000',
         'steady_window_min_min_gbps='+str(rate),'steady_window_max_max_gbps='+str(rate),
         'steady_stddev_max_gbps=0','steady_cv_max_pct=0',
         'episode_window_min_min_gbps='+str(rate),'episode_window_max_max_gbps='+str(rate),
         'episode_stddev_max_gbps=0','episode_cv_max_pct=0','']
    (out/'expect.cfg').write_text('\n'.join(config))
    declarations=[]
    for fields,name in [(WINDOW_FIELDS,'ref_window_t'),(RAW_FIELDS,'ref_raw_t')]:
        declarations.append('typedef struct {\n'+''.join('  '+('real' if field in ('gbps','bpc') else 'ref_u64')+' '+field+';\n' for field in fields)+'} '+name+';\n')
    text='''package bw_scale_input_pkg;
  timeunit 1fs;timeprecision 1fs;
  typedef longint unsigned ref_u64;
'''
    constants=dict(POINTS=s.points,GROUPS=len(s.groups),SCOPES=s.points+len(s.groups),EDGES=s.clock.edges,END_TICKS=s.end,
                   BASIS=0 if s.basis=='ns' else 1,WIDTH=s.width,STRIDE=s.stride,RESET_START=s.reset_start,RESET_END=s.reset_end,UNKNOWN_TICK=s.unknown_tick)
    for k,v in constants.items():text+='  localparam ref_u64 {}=64\'d{};\n'.format(k,v)
    text+='''  int variant=0; //0 baseline,1 unknown-size on p0,2 p0 known reset.
  int actual_fd=0,completed_scopes=0;
  bit observation_end=0;
'''+''.join(declarations)
    text+='''  function automatic ref_u64 clock_tick(ref_u64 edge_index);
    ref_u64 k;k=edge_index;
'''
    for first,period,n in s.clock.segments:text+='    if(k<={})return {}+(k-1)*{};k-={};\n'.format(n,first,period,n)
    text+='''    $fatal(1,"SCALE_REFERENCE_CLOCK edge_index=%0d",edge_index);return0;
  endfunction
  function automatic ref_u64 rank_lt(ref_u64 tick);
    ref_u64 n,total;total=0;
'''.replace('return0','return 0')
    for first,period,count in s.clock.segments:
        text+='    n=0;if(tick>{})n=(tick-{}+{}-1)/{};if(n>{})n={};total+=n;\n'.format(first,first,period,period,count,count)
    text+='''    return total;
  endfunction
  function automatic ref_u64 cardinality(bit is_group,int index);
    if(!is_group)return 1;
    case(index)
'''
    for g in s.groups:text+='      {}:return {};\n'.format(g,len(s.leaves[g]))
    text+='''      default:$fatal(1,"SCALE_REFERENCE_GROUP index=%0d",index);
    endcase
    return 0;
  endfunction
  function automatic ref_u64 direct_count(int index);
    case(index)
'''
    for g,members in s.groups.items():text+='      {}:return {};\n'.format(g,len(members))
    text+='''      default:$fatal(1,"SCALE_REFERENCE_GROUP index=%0d",index);
    endcase
    return 0;
  endfunction
  function automatic bit affected(bit is_group,int index);
    if(!is_group)return index==0;
    case(index)
'''
    affected=[str(g) for g in s.groups if 0 in s.leaves[g]]
    text+='      '+','.join(affected)+':return 1;\n      default:return 0;\n    endcase\n  endfunction\n'
    text+='''  function automatic string expected_id(bit is_group,int index);
    if(is_group)return $sformatf("scale.g%0d",index);
    return $sformatf("tb_bw_scale.points[%0d].slot.mon",index);
  endfunction
  function automatic ref_u64 pre_reset_count();
    if(BASIS==0)return RESET_START/(STRIDE*1000000);
    return (rank_lt(RESET_START)-1)/STRIDE;
  endfunction
  function automatic ref_u64 publication_count(bit own);
    if(own && variant==2)begin
      if(BASIS==0)return pre_reset_count()+(END_TICKS-RESET_END)/(STRIDE*1000000);
      return pre_reset_count()+(EDGES-rank_lt(RESET_END)-1)/STRIDE;
    end
    if(BASIS==0)return END_TICKS/(STRIDE*1000000);
    return (EDGES-1)/STRIDE;
  endfunction
  function automatic ref_window_t interval_counts(ref_u64 m,bit hit,bit own,ref_u64 left,ref_u64 right);
    ref_window_t v;ref_u64 a,b,n;
    v.bytes=64*m*(rank_lt(right)-rank_lt(left));v.events=m*(rank_lt(right)-rank_lt(left));
    v.bytes_complete=1;v.events_complete=1;v.reset=0;
    if(hit && variant==1 && left<=UNKNOWN_TICK && UNKNOWN_TICK<right)begin v.bytes-=64;v.bytes_complete=0;end
    if(hit && variant==2)begin
      a=(left>RESET_START)?left:RESET_START;b=(right<RESET_END)?right:RESET_END;
      if(a<b)begin n=rank_lt(b)-rank_lt(a);v.bytes-=64*n;v.events-=n;v.reset=!own;end
    end
    return v;
  endfunction
  function automatic ref_window_t reference_window(ref_u64 seq,ref_u64 m,bit hit,bit own);
    ref_window_t v;ref_u64 rank,origin,anchor,left,right,lc,rc,cc;bit after_reset,full;
    after_reset=own && variant==2 && seq>pre_reset_count();
    rank=after_reset ? seq-pre_reset_count() : seq;origin=after_reset ? RESET_END : 0;
    lc=0;rc=0;cc=0;
    if(BASIS==0)begin
      right=origin+rank*STRIDE*1000000;left=(right-origin>=WIDTH*1000000)?right-WIDTH*1000000:origin;
      full=right-origin>=WIDTH*1000000;
    end else begin
      anchor=rank_lt(origin)+1;rc=anchor+rank*STRIDE;lc=(rc-anchor>=WIDTH)?rc-WIDTH:anchor;
      left=clock_tick(lc);right=clock_tick(rc);cc=rc-lc;full=cc==WIDTH;
    end
    v=interval_counts(m,hit,own,left,right);v.seq=seq;v.epoch=after_reset;v.left=left;v.right=right;
    v.left_cycle=lc;v.right_cycle=rc;v.coverage_ticks=right-left;v.coverage_cycles=cc;v.full=full;v.warmup=!full;
    v.denominator_valid=right>left;v.window_valid=full && v.bytes_complete && v.denominator_valid;
    v.gbps=v.denominator_valid ? real'(v.bytes)*1000000.0/real'(right-left) : 0;
    v.bpc=(cc!=0)?real'(v.bytes)/real'(cc):0;
    return v;
  endfunction
  function automatic ref_raw_t reference_raw(ref_u64 edge_index,ref_u64 m,bit hit,bit own);
    ref_raw_t r;ref_window_t v,total;ref_u64 tick,left;bit epoch;
    tick=clock_tick(edge_index);epoch=own && variant==2 && tick>=RESET_START;left=epoch ? RESET_END : 0;
    v=interval_counts(m,hit,own,tick,tick+1);
    if(epoch && tick<RESET_END)begin total.bytes=0;total.events=0;end
    else total=interval_counts(m,hit,own,left,tick+1);
    r.seq=edge_index;r.epoch=epoch;r.tick=tick;r.edge_index=edge_index;r.byte_inc=v.bytes;r.event_inc=v.events;
    r.bytes_complete=v.bytes_complete;r.events_complete=v.events_complete;
    r.reset_points=hit && variant==2 && RESET_START<=tick && tick<RESET_END;
    r.total_bytes=total.bytes;r.total_events=total.events;r.source_epoch=epoch;return r;
  endfunction
  function automatic bit close_real(real actual,real expected);
    return $abs(actual-expected)<=1e-9+1e-12*$abs(expected);
  endfunction
endpackage
'''
    (out/'input_pkg.sv').write_text(text)
    # Checker observes public scope outputs only. It never reads DUT histories or derives expected membership from registry data.
    ports=['input bit is_group','input int scope_index','input string scope_id','input bit local_done',
           'input int source_handle','input bw_mon_pkg::bw_record_t raw_record','input logic [63:0] accepted_record_seq']
    for field in WINDOW_FIELDS:ports.append('input '+('real' if field in ('gbps','bpc') else 'logic [63:0]')+' '+PUBLIC[field])
    ports+=['input logic [63:0] total_bytes,total_events']
    # Flags have intentionally widened checker ports; cast at the call site avoids port-width warnings.
    check='module bw_scale_checker(\n  '+',\n  '.join(ports)+'\n);\n'
    check+='''  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;import bw_scale_input_pkg::*;
  ref_u64 windows=0,records=0,m;bit hit,own,done=0;
  ref_window_t window_snapshot;ref_raw_t raw_snapshot;
  initial begin wait(monitor_ready);m=cardinality(is_group,scope_index);hit=affected(is_group,scope_index);own=!is_group && scope_index==0;
    if(scope_id!=expected_id(is_group,scope_index))$fatal(1,"SCALE_ID_MISMATCH expected=%s actual=%s",expected_id(is_group,scope_index),scope_id);
  end
  always @(accepted_record_seq) if(monitor_ready && accepted_record_seq!=0)begin
    ref_raw_t e;records++;e=reference_raw(records,m,hit,own);
'''
    comparisons=['raw_record.record_seq!==records']
    for f,signal in RAW_PUBLIC.items():comparisons.append(signal+'!==e.'+f)
    check+='    if('+ ' ||\n       '.join(comparisons)+')\n'
    check+='''      $fatal(1,"SCALE_RAW_MISMATCH scope=%s checked=%0d receipt=%0d tick=%0d bytes=%0d/%0d events=%0d/%0d total_bytes=%0d/%0d total_events=%0d/%0d quality=%0b/%0b expected=%0b/%0b epoch=%0d/%0d",
        scope_id,records,accepted_record_seq,raw_record.timestamp_ticks,raw_record.byte_inc,e.byte_inc,raw_record.event_inc,e.event_inc,
        total_bytes,e.total_bytes,total_events,e.total_events,raw_record.bytes_complete,raw_record.events_complete,e.bytes_complete,e.events_complete,stats_epoch,e.epoch);
'''
    for f,signal in RAW_PUBLIC.items():check+='    raw_snapshot.'+f+'='+signal+';\n'
    check+='''  end
  always @(result_seq) if(monitor_ready && result_seq!=0)begin
    ref_window_t e;windows++;e=reference_window(windows,m,hit,own);
'''
    comparisons=[('!close_real('+PUBLIC[f]+',e.'+f+')') if f in ('gbps','bpc') else PUBLIC[f]+'!==e.'+f for f in WINDOW_FIELDS]
    check+='    if('+' ||\n       '.join(comparisons)+')\n'
    check+='''      $fatal(1,"SCALE_WINDOW_MISMATCH scope=%s checked=%0d seq=%0d bounds=%0d/%0d expected=%0d/%0d bytes=%0d/%0d events=%0d/%0d quality=%0b/%0b expected=%0b/%0b gbps=%.17g/%.17g",
        scope_id,windows,result_seq,window_start_ticks,window_end_ticks,e.left,e.right,window_bytes,e.bytes,window_events,e.events,
        bytes_complete,events_complete,e.bytes_complete,e.events_complete,bandwidth_gbps,e.gbps);
'''
    for f,signal in PUBLIC.items():check+='    window_snapshot.'+f+'='+signal+';\n'
    check+='''  end
  always @(observation_end or local_done or windows or records)begin
    if(observation_end && local_done && !done && windows==publication_count(own) && records==EDGES)begin
      if(retained_frame_count(source_handle)!=0 || retained_control_count(source_handle)!=0)
        $fatal(1,"SCALE_TRANSPORT_NOT_RELEASED scope=%s",scope_id);
      done=1;
'''
    fmt=['%s','%0d','%s']+['%0d']*4+['%0.17g' if f in ('gbps','bpc') else '%0d' for f in WINDOW_FIELDS]+['%0d']*len(RAW_FIELDS)+['%0d']
    args=['is_group?"group":"point"','scope_index','scope_id','m','is_group?direct_count(scope_index):0','windows','records']
    args+=['window_snapshot.'+f for f in WINDOW_FIELDS]+['raw_snapshot.'+f for f in RAW_FIELDS]+['0']
    check+='      $fdisplay(actual_fd,"'+','.join(fmt)+'",'+','.join(args)+');\n'
    check+='''      completed_scopes++;
    end
  end
endmodule
'''
    (out/'checker.sv').write_text(check)
    analysis='''.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(@Q@),.PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(@SPAN@),.PHASE_K(4),
    .PHASE_STEADY_ENTER_ABS(0),.PHASE_STEADY_ENTER_REL(0),.PHASE_STEADY_EXIT_ABS(0),.PHASE_STEADY_EXIT_REL(0),
    .PHASE_RMS_ENTER_ABS(1e-6),.PHASE_RMS_ENTER_REL(0),.PHASE_RMS_EXIT_ABS(1e-6),.PHASE_RMS_EXIT_REL(0),
    .PHASE_TREND_ABS(1),.PHASE_TREND_REL(0)'''.replace('@Q@','30' if s.basis=='ns' else '60').replace('@SPAN@','20' if s.basis=='ns' else '40')
    win='.WINDOW_BASIS(bw_mon_pkg::bw_basis_t\'(bw_scale_input_pkg::BASIS)),.WINDOW_WIDTH(bw_scale_input_pkg::WIDTH),.UPDATE_STRIDE(bw_scale_input_pkg::STRIDE)'
    def connections(group=False):
        parts=['.is_group(1\'b'+str(int(group))+')']
        parts+=['.scope_index(scope_index)','.scope_id(mon.scope_id)','.local_done(local_done)','.source_handle(mon.transport_source)','.raw_record(mon.raw_record)', '.accepted_record_seq(mon.accepted_record_seq)']
        for f,signal in PUBLIC.items():
            val='mon.'+signal
            if f not in ('gbps','bpc'):val="64'("+val+')'
            parts+=['.'+signal+'('+val+')']
        parts+=['.total_bytes(mon.total_bytes)','.total_events(mon.total_events)']
        return ',\n    '.join(parts)
    top='''module bw_scale_point #(parameter bw_mon_pkg::bw_protocol_t PROTOCOL=bw_mon_pkg::BW_VALID_ONLY,parameter bit DYNAMIC=0)
  (input logic clk,input int scope_index);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;import bw_scale_input_pkg::*;
  logic reset_n=1;logic [63:0] size_bytes=64;bit local_done=0;
  initial begin
    wait(monitor_ready);
    if(scope_index==0 && variant==1)begin #(UNKNOWN_TICK-1);size_bytes='x;#2;size_bytes=64;end
  end
  initial begin
    wait(monitor_ready);
    if(scope_index==0 && variant==2)begin #RESET_START;reset_n=0;#(RESET_END-RESET_START);reset_n=1;end
  end
  bw_point_mon #(@WIN@,.FIXED_BYTES(64),.DYNAMIC_BYTES(DYNAMIC),.PROTOCOL(PROTOCOL),
    .CREDIT_ENABLE(PROTOCOL==BW_CREDIT),.CREDIT_CAPACITY(16),.CREDIT_INITIAL(16),.CREDIT_INITIAL_KNOWN(1),.CREDIT_RETURN_TIMING(BW_RETURN_NEXT_CYCLE),
    .BACKPRESSURE_ENABLE(PROTOCOL==BW_VALID_READY),.BACKPRESSURE_BASIS(bw_basis_t'(BASIS)),.BACKPRESSURE_THRESHOLD(@HINT@),
    .SHORTAGE_ENABLE(PROTOCOL==BW_CREDIT),.SHORTAGE_BASIS(bw_basis_t'(BASIS)),.SHORTAGE_THRESHOLD(@HINT@),@ANALYSIS@) mon
    (.clk(clk),.reset_n(reset_n),.valid(1'b1),.ready(1'b1),.flitv(1'b1),.lcrdv(1'b1),.size_bytes(size_bytes),.size_known(1'b1));
  bw_scale_checker checker(@POINT_CONNECTIONS@);
  always @(observation_end)if(observation_end)begin
    if(mon.raw_control.control_seq!=((scope_index==0 && variant==2)?3:1) ||
       mon.backpressure_supported!=(PROTOCOL==BW_VALID_READY) || mon.backpressure_enabled!=(PROTOCOL==BW_VALID_READY) ||
       mon.shortage_supported!=(PROTOCOL==BW_CREDIT) || mon.shortage_enabled!=(PROTOCOL==BW_CREDIT) ||
       mon.backpressure_hit_count!=0 || mon.shortage_hit_count!=0 ||
       ((PROTOCOL==BW_CREDIT) && (!mon.credit_trusted || mon.credit_anomaly || mon.credit_balance!=16)))
      $fatal(1,"SCALE_HINT_CONTROL_MISMATCH scope=%s protocol=%0d",mon.scope_id,PROTOCOL);
    local_done=1;
  end
endmodule
module bw_scale_group #(parameter string GROUP_ID="") (input logic clk,input int scope_index);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;import bw_scale_input_pkg::*;
  bit local_done=0;
  bw_group_mon #(.GROUP_ID(GROUP_ID),@WIN@,@ANALYSIS@) mon(.clk(clk),.reset_n(1'b1));
  bw_scale_checker checker(@GROUP_CONNECTIONS@);
  always @(observation_end)if(observation_end)begin
    if(mon.direct_member_count!=direct_count(scope_index) || mon.recursive_point_count!=cardinality(1,scope_index) ||
       mon.accepted_control_count!=cardinality(1,scope_index)+((variant==2 && affected(1,scope_index))?2:0))
      $fatal(1,"SCALE_GROUP_MEMBERS_CONTROLS scope=%s",mon.scope_id);
    for(int m=0;m<mon.direct_member_count;m++)
      if(acknowledged_frame_seq(mon.group_handle,m)!=EDGES)$fatal(1,"SCALE_ACK_MISMATCH scope=%s member=%0d",mon.scope_id,m);
    local_done=1;
  end
endmodule
module tb_bw_scale;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;import bw_scale_input_pkg::*;
  logic clk=0;bit deadline=0;string variant_name,actual_path;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(POINTS),.EXPECTED_GROUP_COUNT(GROUPS)) setup();
  for(genvar p=0;p<POINTS;p++)begin:points
    bw_scale_point #(.PROTOCOL(bw_protocol_t'(p%3)),.DYNAMIC(p%2==0)) slot(.clk(clk),.scope_index(p));
  end
  for(genvar g=0;g<GROUPS;g++)begin:groups
    bw_scale_group #(.GROUP_ID($sformatf("scale.g%0d",g))) slot(.clk(clk),.scope_index(g));
  end
  initial begin
    if(!$value$plusargs("VARIANT=%s",variant_name))variant_name="baseline";
    case(variant_name)"baseline":variant=0;"unknown":variant=1;"reset":variant=2;default:$fatal(1,"SCALE_VARIANT_INVALID");endcase
    if(!$value$plusargs("ACTUAL=%s",actual_path))actual_path="actual.csv";
    actual_fd=$fopen(actual_path,"w");if(actual_fd==0)$fatal(1,"SCALE_ACTUAL_OPEN");
    $fdisplay(actual_fd,"@CSV_HEADER@");
@TOPOLOGY@
    finish_configuration();wait(monitor_ready);
    if($time!=0 || measurement_start_ticks!=0)$fatal(1,"SCALE_READY_ORIGIN");
    $display("SCALE_RUN_START points=%0d groups=%0d scopes=%0d edges=%0d end_ticks=%0d basis=%0d W=%0d S=%0d variant=%s waves=0",POINTS,GROUPS,SCOPES,EDGES,END_TICKS,BASIS,WIDTH,STRIDE,variant_name);
    #END_TICKS;deadline<=1;observation_end=1;
    wait(completed_scopes==SCOPES);
    if($time!=END_TICKS || core_failure_pending())$fatal(1,"SCALE_FINAL_FAILURE");
    $fclose(actual_fd);
    $display("SCALE_PASS points=%0d groups=%0d scopes=%0d checked_raw=%0d end_ticks=%0d",POINTS,GROUPS,completed_scopes,EDGES*SCOPES,$time);
    $finish;
  end
  initial begin
    wait(monitor_ready);
    for(ref_u64 k=1;k<=EDGES;k++)begin
      #(clock_tick(k)-$time);clk=1;#1;clk=0;
    end
  end
  initial begin
    wait(monitor_ready);
    for(ref_u64 n=1;n*1000000000<END_TICKS;n++)begin
      #1000000000;
      $display("SCALE_PROGRESS at_ticks=%0d input_edges_before=%0d",$time,rank_lt($time));
    end
  end
  always @(deadline or completed_scopes)if(deadline)begin
    SCALE_ALL_SCOPES_SETTLED:assert final(completed_scopes==SCOPES)else end_failure();
  end
  function automatic void end_failure();
    if(completed_scopes!=SCOPES)$fatal(1,"SCALE_END_INCOMPLETE completed=%0d expected=%0d time=%0d",completed_scopes,SCOPES,$time);
  endfunction
endmodule
'''
    topo=[]
    for g,members in s.groups.items():
        topo.append('    define_group("{}",{});'.format(s.group_id(g),len(members)))
        for kind,index in members:topo.append('    add_{}_member("{}","{}");'.format(kind,s.group_id(g),s.identity(kind,index)))
    for key,value in {'WIN':win,'HINT':'4' if s.basis=='ns' else '8','ANALYSIS':analysis,'POINT_CONNECTIONS':connections(),
                      'GROUP_CONNECTIONS':connections(True),'CSV_HEADER':','.join(CSV_FIELDS),'TOPOLOGY':'\n'.join(topo)}.items():top=top.replace('@'+key+'@',value)
    (out/'tb_bw_scale.sv').write_text(top)
