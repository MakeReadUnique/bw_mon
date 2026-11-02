#!/usr/bin/env python3
"""Publish the declared public analysis surface and concrete fatal-code index."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 out=ROOT/'artifacts/acceptance';fields={}
 for line in (ROOT/'rtl/bw_analysis_public.svh').read_text().splitlines():
  m=re.match(r'\s*(wire|bit|real|bw_\w+_t)\s*(\[[^]]+\])?\s+([^;]+);',line)
  if not m:continue
  for item in m.group(3).split(','):
   name=item.split('=',1)[0].strip()
   if not re.fullmatch(r'\w+',name):continue
   unit='fs' if name.endswith('_ticks') else 'GB/s' if name.endswith('_gbps') else '%' if name.endswith('_pct') else 'bytes' if name.endswith(('byte_count','bytes')) else 'events' if name.endswith('event_count') else 'enum/identity/count/flag'
   fields[name]={'declaration':m.group(1)+' '+(m.group(2) or ''),'unit':unit,'scopes':['point','group'],'meaning':'latest immutable final' if name.startswith(('episode_result_','phase_result_','episode_last_steady_')) or 'variation' in name else 'live analysis or latest final counter; see API'}
 for name in ['scope_id','monitor_path','scope_kind','stats_epoch','result_seq','accepted_record_seq','total_bytes','total_events','window_start_ticks','window_end_ticks','window_start_cycle','window_end_cycle','coverage_ticks','coverage_cycles','window_bytes','window_events','bandwidth_gbps','bytes_per_cycle','window_full','window_warmup','bytes_complete','events_complete','denominator_valid','member_reset_coverage','window_valid','raw_record','raw_control']:
  fields.setdefault(name,{'scopes':['point','group'],'unit':'fs' if name.endswith('_ticks') else 'GB/s' if name=='bandwidth_gbps' else 'B/cycle' if name=='bytes_per_cycle' else 'see API','meaning':'public identity, exact window or normalized source/control boundary'})
 point_names=['clk','reset_n','valid','ready','flitv','lcrdv','size_bytes','size_known','protocol','dynamic_bytes','sampled_reset_n','sampled_valid','sampled_ready','sampled_flitv','sampled_lcrdv','sampled_size_bytes','sampled_size_known']
 point_names +=['credit_'+name for name in ['supported','enabled','trusted','anomaly','state','reason','balance','last_trusted_balance','available_before','attempted_balance','permission_known','shortage_known','send_permitted','shortage','anomaly_count','result_seq','epoch','update_ticks','record_seq','capacity','initial','initial_known','return_timing']]
 for prefix in ['backpressure','shortage']:
  point_names +=[prefix+'_'+name for name in ['basis','threshold','supported','enabled','trusted','active','hit','cycle_anchor_valid','end_reason','epoch','interval_epoch','interval_id','result_seq','start_ticks','trigger_ticks','end_ticks','observed_through_ticks','update_ticks','duration_ticks','start_cycle','end_cycle','duration_cycles','hit_count','interval_count']]
 for name in point_names:fields.setdefault(name,{'scopes':['point'],'unit':'fs' if name.endswith('_ticks') else 'see API','meaning':'live/sample protocol evidence or independent local diagnostic'})
 (out/'public-fields.json').write_text(json.dumps({'actual_paths':{'point':'/<top>/scene/ports[0]/dut/mon/<field>','group':'/<top>/scene/{die0,die1,all_dmc,mixed}/<field>'},'fields':fields,'point_only':'raw/sampled protocol and size; protocol/dynamic policy; credit_*; backpressure_*; shortage_* (see API and per-view signals JSON)','notes':['result_seq is WINDOW only','episode_result_*/phase_result_* identify latest immutable packet; live fields can already describe another episode','selected phase retains ORIGINAL identity/sequence','false validity with real backing0 is not a measured zero','public scopes do not depend on private Core/recorder instance layout']},indent=2)+'\n')
 cases=json.loads((ROOT/'tests/cases.json').read_text());codes={}
 for file in sorted((ROOT/'rtl').glob('*')):
  if file.suffix not in ['.sv','.svh','.vh']:continue
  for number,line in enumerate(file.read_text().splitlines(),1):
   found=re.findall(r'(?:core_error|deferred_core_error)\("([A-Z_]+)"',line)+re.findall(r'deferred_failure_code="([A-Z_]+)"',line)
   for code in found:codes.setdefault(code,{'locations':[],'cases':[]})['locations'].append(str(file.relative_to(ROOT))+':'+str(number))
 for case in cases:
  match=re.search(r'code=([A-Z_]+)',case.get('expect_error',''))
  if match and match.group(1) not in codes:
   code=match.group(1);locations=[]
   for file in sorted((ROOT/'rtl').glob('*')):
    if file.suffix in ['.sv','.svh','.vh']:
     locations +=[str(file.relative_to(ROOT))+':'+str(i) for i,line in enumerate(file.read_text().splitlines(),1) if '"'+code+'"' in line]
   codes[code]={'locations':locations,'cases':[]}
 for code,value in codes.items():value['cases']=[c['name'] for c in cases if code in c.get('expect_error','')]
 (out/'error-catalog.json').write_text(json.dumps(codes,indent=2,sort_keys=True)+'\n')
 print('Catalog:',len(fields),'publicfields;',len(codes),'literal/durable corecodes')
if __name__=='__main__':main()
