# e3_delayed / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 3120 raw records, 3120 receipts and 304 public windows match the stimulus-only reference. Analysis checks: {'episodes': 4, 'phases': 4, 'variations': 8}.

Configuration: W=100, S=10, Q=60 in ns; N=3, span=20, K=4. Physical time quantum1fs; end=196000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[10,110)|640 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p1|[10,110)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[10,110)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[10,110)|640 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|all_dmc|[10,110)|640 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|mixed|[10,110)|640 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p10|[10,110)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[10,110)|0 / 0|0|0|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|95 / 135 / 136 / 196|640 / 2|15.6097560976|15.6097560976|status2; bytes1, events1, member0|
|die0|0 / 1|95 / 135 / 136 / 196|640 / 2|15.6097560976|15.6097560976|status2; bytes1, events1, member0|
|all_dmc|0 / 1|95 / 135 / 136 / 196|640 / 2|15.6097560976|15.6097560976|status2; bytes1, events1, member0|
|mixed|0 / 1|95 / 135 / 136 / 196|640 / 2|15.6097560976|15.6097560976|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[120,136) / 150|0|0|2 / 6.4 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[120,136) / 150|0|0|2 / 6.4 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=PASS pass=4 fail=0 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 4, 'FAIL': 0, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=last_steady phase=1 metric=steady_bw unit=GB/s start_ticks=120000000 end_ticks=136000000 actual=0 has_min=0 min=0 has_max=1 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=1 duration_ticks=16000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=1 basis=0 W=100 S=10 samples=2 first_sample_ticks=120000000 last_sample_ticks=130000000 sample_span_ticks=10000000 mean_gbps=6.4000000000000004 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e3_delayed_ns/expect.cfg min_line=0 max_line=2 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=last_steady phase=1 metric=steady_window_min unit=GB/s start_ticks=120000000 end_ticks=136000000 actual=6.4000000000000004 has_min=1 min=6.4000000000000004 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=6.4000000000000004 effective_max=0 bytes=0 events=1 duration_ticks=16000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=1 basis=0 W=100 S=10 samples=2 first_sample_ticks=120000000 last_sample_ticks=130000000 sample_span_ticks=10000000 mean_gbps=6.4000000000000004 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e3_delayed_ns/expect.cfg min_line=3 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=1 metric=steady_bw unit=GB/s start_ticks=120000000 end_ticks=136000000 actual=0 has_min=0 min=0 has_max=1 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=1 duration_ticks=16000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=1 basis=0 W=100 S=10 samples=2 first_sample_ticks=120000000 last_sample_ticks=130000000 sample_span_ticks=10000000 mean_gbps=6.4000000000000004 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e3_delayed_ns/expect.cfg min_line=0 max_line=5 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=1 metric=steady_window_min unit=GB/s start_ticks=120000000 end_ticks=136000000 actual=6.4000000000000004 has_min=1 min=6.4000000000000004 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=6.4000000000000004 effective_max=0 bytes=0 events=1 duration_ticks=16000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=1 basis=0 W=100 S=10 samples=2 first_sample_ticks=120000000 last_sample_ticks=130000000 sample_span_ticks=10000000 mean_gbps=6.4000000000000004 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e3_delayed_ns/expect.cfg min_line=6 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
