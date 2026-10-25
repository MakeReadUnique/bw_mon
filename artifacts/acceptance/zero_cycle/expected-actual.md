# zero / cycle expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 1904 raw records, 1904 receipts and 944 public windows match the stimulus-only reference. Analysis checks: {'episodes': 4, 'phases': 4, 'variations': 8}.

Configuration: W=20, S=2, Q=24 in cycle; N=3, span=4, K=2. Physical time quantum1fs; end=60000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[20.5,30.5)|0 / 20|0|0|0|1 / 1 / 1 / 0|
|p0|[30.5,40.5)|0 / 19|0|0|0|1 / 1 / 1 / 0|
|p0|[42.5,52.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[20.5,30.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[30.5,40.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[42.5,52.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[20.5,30.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[30.5,40.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[42.5,52.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[20.5,30.5)|0 / 20|0|0|0|1 / 1 / 1 / 0|
|die0|[30.5,40.5)|0 / 19|0|0|0|1 / 1 / 1 / 0|
|die0|[42.5,52.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[20.5,30.5)|0 / 20|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[30.5,40.5)|0 / 19|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[42.5,52.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|mixed|[20.5,30.5)|0 / 20|0|0|0|1 / 1 / 1 / 0|
|mixed|[30.5,40.5)|0 / 19|0|0|0|1 / 1 / 1 / 0|
|mixed|[42.5,52.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[20.5,30.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[30.5,40.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[42.5,52.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[20.5,30.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[30.5,40.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[42.5,52.5)|0 / 0|0|0|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|20 / 39.5 / 40 / 52|0 / 40|0|0|status2; bytes1, events1, member0|
|die0|0 / 1|20 / 39.5 / 40 / 52|0 / 40|0|0|status2; bytes1, events1, member0|
|all_dmc|0 / 1|20 / 39.5 / 40 / 52|0 / 40|0|0|status2; bytes1, events1, member0|
|mixed|0 / 1|20 / 39.5 / 40 / 52|0 / 40|0|0|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[22.5,40) / 23.5|0|0|18 / 0.0 / 0.0 / None|
|all_dmc / 1|STEADY|[22.5,40) / 23.5|0|0|18 / 0.0 / 0.0 / None|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=WARNING pass=6 fail=0 warning=2 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 6, 'FAIL': 0, 'WARNING': 2}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=20000000 end_ticks=40000000 actual=0 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=40 duration_ticks=20000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=20 first_sample_ticks=20500000 last_sample_ticks=39500000 sample_span_ticks=19000000 mean_gbps=0 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=0 minmax_reason=NONE stddev_reason=NONE cv_reason=ZERO_MEAN excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/zero_cycle/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_stddev unit=GB/s start_ticks=20000000 end_ticks=40000000 actual=0 has_min=0 min=0 has_max=1 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=40 duration_ticks=20000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=20 first_sample_ticks=20500000 last_sample_ticks=39500000 sample_span_ticks=19000000 mean_gbps=0 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=0 minmax_reason=NONE stddev_reason=NONE cv_reason=ZERO_MEAN excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/zero_cycle/expect.cfg min_line=0 max_line=4 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=20000000 end_ticks=40000000 actual=UNAVAILABLE has_min=0 min=0 has_max=1 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=40 duration_ticks=20000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=20 first_sample_ticks=20500000 last_sample_ticks=39500000 sample_span_ticks=19000000 mean_gbps=0 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=0 minmax_reason=NONE stddev_reason=NONE cv_reason=ZERO_MEAN excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/zero_cycle/expect.cfg min_line=0 max_line=5 abs_line=0 rel_line=0 conclusion=WARNING reason=ZERO_MEAN
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=last_steady phase=1 metric=steady_bw unit=GB/s start_ticks=22500000 end_ticks=40000000 actual=0 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=35 duration_ticks=17500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=1 basis=1 W=20 S=2 samples=18 first_sample_ticks=22500000 last_sample_ticks=39500000 sample_span_ticks=17000000 mean_gbps=0 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=0 minmax_reason=NONE stddev_reason=NONE cv_reason=ZERO_MEAN excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/zero_cycle/expect.cfg min_line=3 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=20000000 end_ticks=40000000 actual=0 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=40 duration_ticks=20000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=20 first_sample_ticks=20500000 last_sample_ticks=39500000 sample_span_ticks=19000000 mean_gbps=0 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=0 minmax_reason=NONE stddev_reason=NONE cv_reason=ZERO_MEAN excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/zero_cycle/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_stddev unit=GB/s start_ticks=20000000 end_ticks=40000000 actual=0 has_min=0 min=0 has_max=1 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=40 duration_ticks=20000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=20 first_sample_ticks=20500000 last_sample_ticks=39500000 sample_span_ticks=19000000 mean_gbps=0 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=0 minmax_reason=NONE stddev_reason=NONE cv_reason=ZERO_MEAN excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/zero_cycle/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=20000000 end_ticks=40000000 actual=UNAVAILABLE has_min=0 min=0 has_max=1 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=40 duration_ticks=20000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=20 first_sample_ticks=20500000 last_sample_ticks=39500000 sample_span_ticks=19000000 mean_gbps=0 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=0 minmax_reason=NONE stddev_reason=NONE cv_reason=ZERO_MEAN excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/zero_cycle/expect.cfg min_line=0 max_line=10 abs_line=0 rel_line=0 conclusion=WARNING reason=ZERO_MEAN
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=1 metric=steady_bw unit=GB/s start_ticks=22500000 end_ticks=40000000 actual=0 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=35 duration_ticks=17500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=1 basis=1 W=20 S=2 samples=18 first_sample_ticks=22500000 last_sample_ticks=39500000 sample_span_ticks=17000000 mean_gbps=0 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=0 minmax_reason=NONE stddev_reason=NONE cv_reason=ZERO_MEAN excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/zero_cycle/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
