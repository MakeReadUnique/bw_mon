"""Public-entry SV fixture for the independent expanded-event history oracle."""
import csv
import json
from fractions import Fraction
from pathlib import Path

RAW = dict(seq='accepted_record_seq', epoch='stats_epoch', tick='raw_record.timestamp_ticks',
           edge_index='raw_record.edge_index', byte_inc='raw_record.byte_inc', event_inc='raw_record.event_inc',
           bytes_complete='raw_record.bytes_complete', events_complete='raw_record.events_complete',
           reset_points='raw_record.reset_points', total_bytes='total_bytes', total_events='total_events',
           source_epoch='raw_record.source_epoch')
WINDOW = dict(seq='result_seq', epoch='stats_epoch', left='window_start_ticks', right='window_end_ticks',
              left_cycle='window_start_cycle', right_cycle='window_end_cycle', coverage_ticks='coverage_ticks',
              coverage_cycles='coverage_cycles', bytes='window_bytes', events='window_events', warmup='window_warmup',
              full='window_full', bytes_complete='bytes_complete', events_complete='events_complete',
              denominator_valid='denominator_valid', window_valid='window_valid', reset='member_reset_coverage',
              gbps='bandwidth_gbps', bpc='bytes_per_cycle')
REAL = ('gbps', 'bpc')
SUMMARY = ('scope', 'records', 'windows', 'total_bytes', 'total_events', 'event_segments_peak', 'clock_segments_peak',
           'phase_samples_peak', 'episode_pending_runs_peak', 'episode_pending_count_peak',
           'phase_pending_runs_peak', 'phase_pending_count_peak', 'event_segments_final', 'clock_segments_final',
           'transport_frames_final', 'transport_controls_final', 'drain_checkpoints')


def text(value):
    return format(float(value), '.17g') if isinstance(value, Fraction) else str(value)


def generate(s, out):
    out.mkdir(parents=True, exist_ok=True)
    oracle = s.oracle
    (out/'input.json').write_text(json.dumps(s.manifest(), indent=2, sort_keys=True)+'\n')
    (out/'event-input.txt').write_text(''.join(' '.join(map(str, event))+'\n' for event in oracle.events))
    final = []
    for scope in range(3):
        with (out/('raw-%d.txt' % scope)).open('w') as handle:
            for edge in range(1, len(oracle.events)+1):
                row = oracle.raw(scope, edge)
                handle.write(' '.join(text(row[field]) for field in RAW)+'\n')
        with (out/('window-%d.txt' % scope)).open('w') as handle:
            for row in oracle.windows(scope):
                handle.write(' '.join(text(row[field]) for field in WINDOW)+'\n')
        row = dict(scope=scope, records=len(oracle.events), windows=oracle.publication_counts[scope])
        row.update({'raw_'+k: text(v) for k, v in oracle.raw(scope, len(oracle.events)).items()})
        row.update({'window_'+k: text(v) for k, v in oracle.window(scope, oracle.publication_counts[scope]).items()})
        final.append(row)
    with (out/'expected.csv').open('w') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(final[0]))
        writer.writeheader(); writer.writerows(final)
    cfg = []
    for scope in range(3):
        sid = 'group history.group' if scope == 2 else 'point history.p%d' % scope
        cfg += ['['+sid+']', 'e2e_bw_min_gbps=0', 'episode_cv_max_pct=1000000', '']
    (out/'expect.cfg').write_text('\n'.join(cfg))
    package = '''package bw_history_input_pkg;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  int actual_fd=0,storage_fd=0,completed_scopes=0;
  bit observation_end=0;
'''
    counts = oracle.publication_counts
    params = dict(BASIS=int(s.basis == 'cycle'), WIDTH=s.width, STRIDE=s.stride,
                  EDGES=len(oracle.events), WINDOWS=sum(counts), END_TICKS=oracle.end,
                  EXPIRY=int(s.kind == 'expiry'),
                  SNAPSHOT_STRIDE=0 if s.kind in ('deep', 'overrun') else 512 if s.kind == 'expiry' else 16384 if s.kind == 'reset' else 64,
                  WINDOWS_0=counts[0], WINDOWS_1=counts[1], WINDOWS_2=counts[2],
                  OVERRUN_EDGES=getattr(s, 'overrun_edges', 0))
    for prefix in ('P0', 'G'):
        params.setdefault(prefix+'_RESET_ASSERT', 0)
        params.setdefault(prefix+'_RESET_RELEASE', 0)
    for scope, intervals in sorted(getattr(s, 'resets', {}).items()):
        name = 'P0' if scope == 0 else 'G'
        params[name+'_RESET_ASSERT'], params[name+'_RESET_RELEASE'] = intervals[0]
    params['RESETS'] = int(bool(getattr(s, 'resets', {})))
    for key, value in params.items():
        package += '  localparam bw_u64_t %s=64\'d%d;\n' % (key, value)
    package += '''  function automatic bw_u64_t expected_windows(int scope);
    case(scope) 0:return WINDOWS_0; 1:return WINDOWS_1; default:return WINDOWS_2; endcase
  endfunction
'''
    package += '''  function automatic bit close_real(real actual,real expected);
    return $abs(actual-expected)<=1e-9+1e-12*$abs(expected);
  endfunction
endpackage
'''
    (out/'input_pkg.sv').write_text(package)
    ports = ['input int scope_index', 'input bit local_done', 'input int source_handle', 'input string scope_id',
             'input bw_mon_pkg::bw_record_t raw_record', 'input logic [63:0] accepted_record_seq,total_bytes,total_events']
    ports += ['input '+('real' if field in REAL else 'logic [63:0]')+' '+signal for field, signal in WINDOW.items()]
    checker = 'module bw_history_checker(\n  '+',\n  '.join(ports)+'\n);\n'
    checker += '''  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;import bw_history_input_pkg::*;
  bw_u64_t records=0,windows=0;
  int raw_fd=0,window_fd=0,rc;
  string directory;
  bit done=0;
  int event_peak=0,clock_peak=0,phase_peak=0,ep_runs_peak=0,ep_count_peak=0,ph_runs_peak=0,ph_count_peak=0;
  int event_final=0,clock_final=0,drains=0;bw_u64_t last_drain=0;
  initial begin
    if(!$value$plusargs("HISTORY_DIR=%s",directory))$fatal(1,"HISTORY_DIRECTORY_REQUIRED");
    wait(monitor_ready);
    raw_fd=$fopen($sformatf("%s/raw-%0d.txt",directory,scope_index),"r");
    window_fd=$fopen($sformatf("%s/window-%0d.txt",directory,scope_index),"r");
    if(!raw_fd || !window_fd)$fatal(1,"HISTORY_REFERENCE_OPEN");
  end
  task automatic observe_storage(int ev,int ck,int ph,int er,int ec,int pr,int pc);
    if(ev>event_peak)event_peak=ev;if(ck>clock_peak)clock_peak=ck;if(ph>phase_peak)phase_peak=ph;
    if(er>ep_runs_peak)ep_runs_peak=er;if(ec>ep_count_peak)ep_count_peak=ec;
    if(pr>ph_runs_peak)ph_runs_peak=pr;if(pc>ph_count_peak)ph_count_peak=pc;
    event_final=ev;clock_final=ck;
    if(EXPIRY && accepted_record_seq!=0 && accepted_record_seq%2048==0 && accepted_record_seq!=last_drain)begin
      if(ev!=0)$fatal(1,"HISTORY_DRAIN_MISMATCH scope=%s edge=%0d segments=%0d",scope_id,accepted_record_seq,ev);
      drains++;last_drain=accepted_record_seq;
    end
  endtask
'''
    for kind, fields, signal in [('raw', RAW, 'accepted_record_seq'), ('window', WINDOW, 'result_seq')]:
        count = 'records' if kind == 'raw' else 'windows'
        checker += '  always @(%s) if(monitor_ready && %s!=0)begin\n' % (signal, signal)
        for field in fields:
            checker += '    '+('real' if field in REAL else 'bw_u64_t')+' e_'+field+';\n'
        checker += '    '+count+'++;\n'
        checker += '    rc=$fscanf('+kind+'_fd,"'+' '.join('%f' if f in REAL else '%d' for f in fields)+'\\n",'+','.join('e_'+f for f in fields)+');\n'
        checker += '    if(rc!=%d)$fatal(1,"HISTORY_REFERENCE_EOF scope=%%s kind=%s checked=%%0d",scope_id,%s);\n' % (len(fields), kind, count)
        for field in ('tick',) if kind == 'raw' else ('left', 'right'):
            checker += '    e_'+field+'+=measurement_start_ticks;\n'
        for field, observed in fields.items():
            condition = '!close_real(%s,e_%s)' % (observed, field) if field in REAL else '%s!==e_%s' % (observed, field)
            checker += '    if('+condition+')$fatal(1,"HISTORY_'+kind.upper()+'_MISMATCH scope=%s checked=%0d field='+field+' actual=%0.17g expected=%0.17g",scope_id,'+count+','+observed+',e_'+field+');\n'
        if kind == 'raw':
            checker += '    if(raw_record.record_seq!=records)$fatal(1,"HISTORY_ORIGINAL_SEQUENCE");\n'
        checker += '  end\n'
    checker += '''  always @(observation_end or local_done or windows or records)begin
    if(observation_end && local_done && !done && windows==expected_windows(scope_index) && records==EDGES)begin
      bw_u64_t surplus;
      if($fscanf(raw_fd,"%d",surplus)!=-1 || $fscanf(window_fd,"%d",surplus)!=-1)
        $fatal(1,"HISTORY_REFERENCE_UNCONSUMED scope=%s",scope_id);
      if(retained_frame_count(source_handle)!=0 || retained_control_count(source_handle)!=0)
        $fatal(1,"HISTORY_TRANSPORT_NOT_RELEASED scope=%s",scope_id);
      done=1;
'''
    args = ['scope_index', 'records', 'windows', 'total_bytes', 'total_events', 'event_peak', 'clock_peak', 'phase_peak',
            'ep_runs_peak', 'ep_count_peak', 'ph_runs_peak', 'ph_count_peak', 'event_final', 'clock_final',
            'retained_frame_count(source_handle)', 'retained_control_count(source_handle)', 'drains']
    checker += '      $fdisplay(actual_fd,"'+','.join(['%0d']*len(args))+'",'+','.join(args)+');\n'
    checker += '''      $fclose(raw_fd);$fclose(window_fd);completed_scopes++;
    end
  end
endmodule
'''
    (out/'checker.sv').write_text(checker)
    analysis = '.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(%d)' % (30 if s.basis == 'ns' else 60)
    window = ".WINDOW_BASIS(bw_basis_t'(BASIS)),.WINDOW_WIDTH(WIDTH),.UPDATE_STRIDE(STRIDE),"+analysis
    storage = '''  int snapshot_seq=0;
  bw_u64_t last_snapshot_edge=0;
  task automatic dump_storage();
    snapshot_seq++;
    $fdisplay(storage_fd,"S %0d %0d %0d %0d %0d %0d",scope_index,snapshot_seq,$time,
      mon.accepted_record_seq,mon.window_start_ticks,mon.window_start_cycle);
    foreach(mon.core.history[i])begin
      $fdisplay(storage_fd,"E %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
        scope_index,snapshot_seq,mon.core.history[i].first_ticks,mon.core.history[i].first_edge,
        mon.core.history[i].count,mon.core.history[i].step_ticks,mon.core.history[i].step_edges,
        mon.core.history[i].byte_inc,mon.core.history[i].event_inc,mon.core.history[i].bytes_complete,
        mon.core.history[i].events_complete,mon.core.history[i].has_reset,mon.core.history[i].last_ticks,mon.core.history[i].last_edge);
    end
    foreach(mon.core.clock_runs[i])begin
      $fdisplay(storage_fd,"C %0d %0d %0d %0d %0d %0d %0d",scope_index,snapshot_seq,
        mon.core.clock_runs[i].first_ticks,mon.core.clock_runs[i].first_edge,mon.core.clock_runs[i].count,
        mon.core.clock_runs[i].step_ticks,mon.core.clock_runs[i].last_ticks);
    end
    $fdisplay(storage_fd,"Z %0d %0d",scope_index,snapshot_seq);
  endtask
  always @(observation_end or mon.result_seq or mon.accepted_record_seq)
    if(observation_end && mon.result_seq==expected_windows(scope_index) && mon.accepted_record_seq==EDGES && !local_done)
      begin dump_storage();local_done=1;end
  always @(mon.accepted_record_seq or mon.result_seq)if(monitor_ready)begin
    int ep_count,ph_count;
    ep_count=0;ph_count=0;
    foreach(mon.core.episode_pending_samples[i])ep_count+=mon.core.episode_pending_samples[i].count;
    foreach(mon.core.phase_pending_samples[i])ph_count+=mon.core.phase_pending_samples[i].count;
    checker.observe_storage(mon.core.history.size(),mon.core.clock_runs.size(),mon.core.phase_samples.size(),
      mon.core.episode_pending_samples.size(),ep_count,mon.core.phase_pending_samples.size(),ph_count);
    if(SNAPSHOT_STRIDE!=0 && mon.accepted_record_seq!=0 && mon.accepted_record_seq%SNAPSHOT_STRIDE==0 &&
       last_snapshot_edge!=mon.accepted_record_seq)begin
      dump_storage();last_snapshot_edge=mon.accepted_record_seq;
    end
  end
'''
    connects = ['.scope_index(scope_index)', '.local_done(local_done)', '.source_handle(mon.transport_source)', '.scope_id(mon.scope_id)',
                '.raw_record(mon.raw_record)', '.accepted_record_seq(mon.accepted_record_seq)',
                '.total_bytes(mon.total_bytes)', '.total_events(mon.total_events)']
    connects += ['.'+signal+'('+('mon.'+signal if field in REAL else "64'(mon."+signal+')')+')' for field, signal in WINDOW.items()]
    check_instance = '  bit local_done=0;\n  bw_history_checker checker('+',\n    '.join(connects)+');\n'
    top = '''module bw_history_point #(parameter int INDEX=0)(input logic clk,valid,known,reset_n,input logic [63:0] size_bytes,input int scope_index);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;import bw_history_input_pkg::*;
  bw_point_mon #(.POINT_ID($sformatf("history.p%0d",INDEX)),.DYNAMIC_BYTES(1),'''+window+''') mon
    (.clk(clk),.reset_n(reset_n),.valid(valid),.size_bytes(size_bytes),.size_known(known));
'''+check_instance+storage+'endmodule\n'
    top += '''module bw_history_group(input logic clk,reset_n,input int scope_index);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;import bw_history_input_pkg::*;
  bw_group_mon #(.GROUP_ID("history.group"),'''+window+''') mon(.clk(clk),.reset_n(reset_n));
'''+check_instance+storage+'endmodule\n'
    top += '''module tb_bw_scale;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;import bw_history_input_pkg::*;
  logic clk=0,valid0=0,valid1=0,known0=1,known1=1;
  logic [63:0] bytes0=0,bytes1=0;
  logic reset_p0=1,reset_g=1;
  bit deadline=0,overrun_done=0;
  string directory,actual_path;
  bw_mon_setup setup();
  bw_history_point #(.INDEX(0)) p0(clk,valid0,known0,reset_p0,bytes0,0);
  bw_history_point #(.INDEX(1)) p1(clk,valid1,known1,1'b1,bytes1,1);
  bw_history_group g0(clk,reset_g,2);
  initial begin
    if(!$value$plusargs("HISTORY_DIR=%s",directory) || !$value$plusargs("ACTUAL=%s",actual_path))
      $fatal(1,"HISTORY_ARGUMENTS_REQUIRED");
    storage_fd=$fopen({directory,"/storage-runs.txt"},"w");if(!storage_fd)$fatal(1,"HISTORY_STORAGE_OPEN");
    actual_fd=$fopen(actual_path,"w");if(!actual_fd)$fatal(1,"HISTORY_ACTUAL_OPEN");
    $fdisplay(actual_fd,"'''+','.join(SUMMARY)+'''");
    add_point_member("history.group","history.p0");add_point_member("history.group","history.p1");
    wait(monitor_ready);
    if($time!=measurement_start_ticks || measurement_start_ticks==0)$fatal(1,"HISTORY_READY_ORIGIN");
    // Known numeric API literals complement the actual >32-bit public sums.
    if(checked_add(64'hffffffffffffffff,0,"history.numeric")!=64'hffffffffffffffff ||
       checked_mul(64'hffffffffffffffff,1,"history.numeric")!=64'hffffffffffffffff ||
       checked_sub(64'hffffffffffffffff,64'hfffffffffffffffe,"history.numeric")!=1 ||
       checked_mul(16384,checked_mul(80001,64'd4294967295,"history.numeric"),"history.numeric")!=64'd5629569901646561280 ||
       ns_to_ticks(40000,"history.numeric")!=64'd40000000000)
      $fatal(1,"HISTORY_NUMERIC_LITERAL");
    $display("HISTORY_RUN_START scopes=3 edges=%0d windows=%0d end_ticks=%0d",EDGES,WINDOWS,END_TICKS);
    #END_TICKS;observation_end=1;deadline<=1;
    wait(completed_scopes==3);
    if(OVERRUN_EDGES!=0)begin
      wait(overrun_done);
      // Detectable over-budget sampling is a runtime warning with isolation:
      // both points stop accepting and the dependent group is disabled, while
      // the in-budget endpoint evidence above remains intact.
      if(!scope_disabled(BW_POINT,"history.p0") || !scope_disabled(BW_POINT,"history.p1") ||
         !scope_disabled(BW_GROUP,"history.group"))$fatal(1,"HISTORY_OVERRUN_NOT_ISOLATED");
      if(p0.mon.accepted_record_seq!=EDGES || p1.mon.accepted_record_seq!=EDGES ||
         g0.mon.accepted_record_seq!=EDGES)$fatal(1,"HISTORY_OVERRUN_ACCEPTED_PAST_BUDGET");
    end else begin
      if($time!=measurement_start_ticks+END_TICKS || core_failure_pending())$fatal(1,"HISTORY_FINAL_FAILURE");
    end
    if(core_failure_pending())$fatal(1,"HISTORY_FINAL_FAILURE");
    if(acknowledged_frame_seq(g0.mon.group_handle,0)!=EDGES || acknowledged_frame_seq(g0.mon.group_handle,1)!=EDGES)
      $fatal(1,"HISTORY_ACK_INCOMPLETE");
    $fclose(actual_fd);$fclose(storage_fd);
    $display("HISTORY_PASS scopes=3 raw=%0d windows=%0d end_ticks=%0d",EDGES*3,WINDOWS,$time);
    // Same ending-contract settle step as the scale driver: the endpoint
    // marker keeps its tick and the final input slot closes before finish.
    // A run that ends exactly at the immutable T+40us budget must finish in
    // that same tick: the budget supports same-tick endpoint work only and
    // must not be drained through an extra tick.
    if(END_TICKS<BW_MONITOR_LIMIT_TICKS)#1;
    $finish;
  end
  initial begin
    if(RESETS)begin
      wait(monitor_ready);
      #(measurement_start_ticks+P0_RESET_ASSERT-$time);reset_p0=0;
      #(measurement_start_ticks+P0_RESET_RELEASE-$time);reset_p0=1;
    end
  end
  initial begin
    if(RESETS)begin
      wait(monitor_ready);
      #(measurement_start_ticks+G_RESET_ASSERT-$time);reset_g=0;
      #(measurement_start_ticks+G_RESET_RELEASE-$time);reset_g=1;
    end
  end
  initial begin
    int fd,rc,v0,k0,v1,k1;
    bw_u64_t tick,b0,b1;
    wait(monitor_ready);
    fd=$fopen({directory,"/event-input.txt"},"r");if(!fd)$fatal(1,"HISTORY_INPUT_OPEN");
    for(bw_u64_t i=1;i<=EDGES;i++)begin
      rc=$fscanf(fd,"%d %d %d %d %d %d %d\\n",tick,v0,k0,b0,v1,k1,b1);
      if(rc!=7)$fatal(1,"HISTORY_INPUT_EOF edge=%0d",i);
      #(measurement_start_ticks+tick-$time-1);valid0=(v0==2)?1'bx:v0[0];known0=k0[0];bytes0=b0;
      valid1=(v1==2)?1'bx:v1[0];known1=k1[0];bytes1=b1;
      #1;clk=1;#1;clk=0;
    end
    if($fscanf(fd,"%d",tick)!=-1)$fatal(1,"HISTORY_INPUT_UNCONSUMED");$fclose(fd);
    // Deliberate real sampling edges past the immutable T+40us budget.
    for(bw_u64_t i=1;i<=OVERRUN_EDGES;i++)begin
      #(measurement_start_ticks+tick+i*500000-$time-1);valid0=1;known0=1;bytes0=64;
      valid1=1;known1=1;bytes1=64;
      #1;clk=1;#1;clk=0;
    end
    if(OVERRUN_EDGES!=0)overrun_done=1;
  end
  always @(deadline or completed_scopes)if(deadline)begin
    HISTORY_ALL_SETTLED:assert final(completed_scopes==3)else end_failure();
  end
  function automatic void end_failure();
    if(completed_scopes!=3)$fatal(1,"HISTORY_END_INCOMPLETE completed=%0d",completed_scopes);
  endfunction
endmodule
'''
    (out/'tb_bw_scale.sv').write_text(top)
