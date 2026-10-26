"""Measured pending-suffix replay at the existing public variation seam."""
import hashlib
import json
from pathlib import Path
import re

SOURCE = Path(__file__).resolve().parents[1]/'tb_variation_pending_retention.sv'


class PendingScenario:
    name = 'history-revised-pending'
    source_module = 'history_revised'
    budget_seconds = 300
    source_files = [SOURCE]

    def manifest(self):
        return dict(schema='revised-history-pending-v1', properties=['H5'],
                    public_entry='bw_point_mon', points=1, groups=0, basis='ns', width=1, stride=1,
                    phase=dict(N=3, K=60000, minimum_span=2, rms_abs=1000, trend_abs=1,
                               steady_abs=0, all_relative=0), silence_threshold=30000,
                    first_edge_ticks=250000, real_edges=7, selected_transfers=6, transferred_bytes=48,
                    end_ticks=30003250001, expected_windows=30003, pending_samples_minimum=30000,
                    expected_selected_samples=3, expected_sample_ticks=[1000000, 2000000, 3000000],
                    source=str(SOURCE.relative_to(SOURCE.parents[1])), source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                    waveform=False, hints='disabled', original_seam='existing public variation_pending_retention contract')

    def generate(self, out):
        out.mkdir(parents=True, exist_ok=True)
        (out/'input.json').write_text(json.dumps(self.manifest(), indent=2, sort_keys=True)+'\n')
        (out/'expected.csv').write_text('windows,pending_samples_minimum,selected_samples\n30003,30000,3\n')
        (out/'expect.cfg').write_text('')
        (out/'input_pkg.sv').write_text('// Existing production contract uses no generated package.\n')
        (out/'checker.sv').write_text('// Assertions are in the public fixture.\n')
        original = SOURCE.read_text()
        (out/'component-source.sv').write_text(original)
        source = original.replace('module tb_variation_pending_retention;', 'module tb_bw_scale;')
        instrumentation = '''  int episode_runs_peak=0,phase_runs_peak=0,episode_count_peak=0,phase_count_peak=0;
  int history_peak=0,clock_peak=0;
  always @(point_mon.result_seq)if(monitor_ready && point_mon.result_seq!=0)begin
    int ep,ph;
    ep=0;ph=0;
    foreach(point_mon.core.episode_pending_samples[i])ep+=point_mon.core.episode_pending_samples[i].count;
    foreach(point_mon.core.phase_pending_samples[i])ph+=point_mon.core.phase_pending_samples[i].count;
    if(ep>episode_count_peak)episode_count_peak=ep;
    if(ph>phase_count_peak)phase_count_peak=ph;
    if(point_mon.core.episode_pending_samples.size()>episode_runs_peak)episode_runs_peak=point_mon.core.episode_pending_samples.size();
    if(point_mon.core.phase_pending_samples.size()>phase_runs_peak)phase_runs_peak=point_mon.core.phase_pending_samples.size();
    if(point_mon.core.history.size()>history_peak)history_peak=point_mon.core.history.size();
    if(point_mon.core.clock_runs.size()>clock_peak)clock_peak=point_mon.core.clock_runs.size();
  end
'''
        source = source.replace('  initial begin', instrumentation+'  initial begin', 1)
        source = source.replace('    $display("TB_PASS variation_pending_retention', '''    if(episode_count_peak<30000 || phase_count_peak<30000 ||
       point_mon.core.episode_pending_samples.size()!=0 || point_mon.core.phase_pending_samples.size()!=0)
      $fatal(1,"HISTORY_PENDING_RETENTION_OR_RELEASE");
    $display("HISTORY_PENDING_STORAGE episode_runs_peak=%0d episode_count_peak=%0d phase_runs_peak=%0d phase_count_peak=%0d history_peak=%0d clock_peak=%0d episode_final=%0d phase_final=%0d",episode_runs_peak,episode_count_peak,phase_runs_peak,phase_count_peak,history_peak,clock_peak,point_mon.core.episode_pending_samples.size(),point_mon.core.phase_pending_samples.size());
    $display("TB_PASS variation_pending_retention''')
        (out/'tb_bw_scale.sv').write_text(source)

    def simulation_args(self, attempt):
        return []

    def verify(self, attempt):
        log = (attempt/'simulation.log').read_text() if (attempt/'simulation.log').exists() else ''
        errors = []
        if len(re.findall(r'^TB_PASS variation_pending_retention ', log, re.M)) != 1 or re.search(r'Fatal:|Error-\[|BW_CORE_ERROR', log):
            errors.append('public_literal_contract_failed')
        rows = re.findall(r'^HISTORY_PENDING_STORAGE (.*)$', log, re.M)
        resource = {}
        if len(rows) != 1:
            errors.append('storage_measurement_missing')
        else:
            resource = {k:int(v) for k,v in re.findall(r'(\w+)=(\d+)', rows[0])}
            if (resource.get('episode_count_peak', 0) < 30000 or resource.get('phase_count_peak', 0) < 30000 or
                    resource.get('episode_final') != 0 or resource.get('phase_final') != 0):
                errors.append('pending_retention_or_release')
        def require_packet(prefix, fields):
            packets = [dict(re.findall(r'(\w+)=([^\s]+)', line)) for line in log.splitlines() if line.startswith(prefix+' ')]
            if len(packets) != 1:
                errors.append(prefix+'_packet_count')
                return
            for field, expected in fields.items():
                if packets[0].get(field) != str(expected):
                    errors.append(prefix+'_'+field)
        require_packet('BW_EPISODE', dict(scope='pending.subject', scope_kind=0, epoch=0, episode=1, result_seq=1,
                       status=2, first_ticks=250000, last_ticks=2750000, tail_ticks=3250000,
                       confirm_ticks=30003250000, bytes=48, events=6, duration_ticks=3000000,
                       first_known=1, last_known=1, tail_known=1, bytes_complete=1, events_complete=1,
                       member_reset=0, e2e_valid=1, e2e_gbps=16))
        require_packet('BW_VARIATION', dict(scope='pending.subject', epoch=0, episode=1, phase=0, result_seq=1,
                       interval='EPISODE', start_ticks=250000, end_ticks=3250000, basis=0, W=1, S=1,
                       samples=3, first_sample_ticks=1000000, last_sample_ticks=3000000, sample_span_ticks=2000000,
                       mean_gbps=16, min_gbps=16, max_gbps=16, stddev_gbps=0, cv_pct=0,
                       interval_known=1, coverage_complete=1, minmax_valid=1, stddev_valid=1, cv_valid=1,
                       excluded_warmup=0, excluded_foreign=0, unknown_samples=0, excluded_denominator=0))
        require_packet('BW_LAST_STEADY', dict(scope='pending.subject', epoch=0, episode=1, result_seq=1,
                       found=0, selection_valid=0, phase=0, phase_result_seq=0))
        require_packet('BW_SUMMARY', dict(status='STATISTICS_ONLY', **{'pass':0, 'fail':0, 'warning':0,
                       'scopes_done':1, 'scopes_expected':1}))
        if any(line.startswith(('BW_PHASE ', 'BW_PHASE_METRICS ', 'BW_CHECK ')) for line in log.splitlines()):
            errors.append('unexpected_pending_phase_or_check')
        if resource and (set(resource) != {'episode_runs_peak', 'episode_count_peak', 'phase_runs_peak', 'phase_count_peak',
                                         'history_peak', 'clock_peak', 'episode_final', 'phase_final'} or
                         resource.get('episode_count_peak') != 30000 or resource.get('phase_count_peak') != 30000):
            errors.append('complete_exact_pending_measurement')
        result = dict(profile=self.name, difference_count=len(errors), checked_raw=7, checked_windows=30003,
                      selected_samples=3, selected_sample_ticks=[1000000, 2000000, 3000000],
                      mean_gbps=16, stddev_gbps=0, cv_pct=0, resource_measurements=resource)
        (attempt/'diffs.json').write_text(json.dumps(errors, indent=2)+'\n')
        (attempt/'verification.json').write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
        return not errors, result
