# e3_boundary / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 496 raw records, 496 receipts and 2720 public windows match the stimulus-only reference. Analysis checks: {'episodes': 8, 'phases': 16, 'variations': 24}.

Configuration: W=10, S=1, Q=30 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=170000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[92,102)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p1|[92,102)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[92,102)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[92,102)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|all_dmc|[92,102)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|mixed|[92,102)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p10|[92,102)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[92,102)|0 / 0|0|0|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|80 / 100 / 102 / 132|256 / 3|11.6363636364|11.6363636364|status2; bytes1, events1, member0|
|p0|0 / 2|132 / 132 / 134 / 164|128 / 1|64|64|status2; bytes1, events1, member0|
|die0|0 / 1|80 / 100 / 102 / 132|256 / 3|11.6363636364|11.6363636364|status2; bytes1, events1, member0|
|die0|0 / 2|132 / 132 / 134 / 164|128 / 1|64|64|status2; bytes1, events1, member0|
|all_dmc|0 / 1|80 / 100 / 102 / 132|256 / 3|11.6363636364|11.6363636364|status2; bytes1, events1, member0|
|all_dmc|0 / 2|132 / 132 / 134 / 164|128 / 1|64|64|status2; bytes1, events1, member0|
|mixed|0 / 1|80 / 100 / 102 / 132|256 / 3|11.6363636364|11.6363636364|status2; bytes1, events1, member0|
|mixed|0 / 2|132 / 132 / 134 / 164|128 / 1|64|64|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[83,85) / 84|64|64|2 / 6.4 / 0.0 / 0.0|
|p0 / 1|STEADY|[87,91) / 88|0|0|4 / 19.2 / 0.0 / 0.0|
|p0 / 1|STEADY|[93,95) / 94|0|0|2 / 12.8 / 0.0 / 0.0|
|p0 / 1|STEADY|[97,101) / 98|16|16|4 / 0.0 / 0.0 / None|
|all_dmc / 1|STEADY|[83,85) / 84|64|64|2 / 6.4 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[87,91) / 88|0|0|4 / 19.2 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[93,95) / 94|0|0|2 / 12.8 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[97,101) / 98|16|16|4 / 0.0 / 0.0 / None|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=PASS pass=4 fail=0 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 4, 'FAIL': 0, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=80000000 end_ticks=102000000 actual=11.636363636363637 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=256 events=3 duration_ticks=22000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=21 first_sample_ticks=81000000 last_sample_ticks=101000000 sample_span_ticks=20000000 mean_gbps=9.4476190476190478 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e3_boundary_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=80000000 end_ticks=102000000 actual=11.636363636363637 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=256 events=3 duration_ticks=22000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=21 first_sample_ticks=81000000 last_sample_ticks=101000000 sample_span_ticks=20000000 mean_gbps=9.4476190476190478 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e3_boundary_ns/expect.cfg min_line=4 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=2 result_seq=2 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=132000000 end_ticks=134000000 actual=64 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=128 events=1 duration_ticks=2000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=1 first_sample_ticks=133000000 last_sample_ticks=133000000 sample_span_ticks=0 mean_gbps=12.800000000000001 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=0 cv_valid=0 minmax_reason=NONE stddev_reason=TOO_FEW_SAMPLES cv_reason=TOO_FEW_SAMPLES excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e3_boundary_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=2 result_seq=2 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=132000000 end_ticks=134000000 actual=64 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=128 events=1 duration_ticks=2000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=1 first_sample_ticks=133000000 last_sample_ticks=133000000 sample_span_ticks=0 mean_gbps=12.800000000000001 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=0 cv_valid=0 minmax_reason=NONE stddev_reason=TOO_FEW_SAMPLES cv_reason=TOO_FEW_SAMPLES excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e3_boundary_ns/expect.cfg min_line=4 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
