# no_episode / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 1904 raw records, 1904 receipts and 960 public windows match the stimulus-only reference. Analysis checks: {'episodes': 0, 'phases': 0, 'variations': 0}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=60000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[20,30)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p0|[30,40)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p0|[42,52)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[20,30)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[30,40)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[42,52)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[20,30)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[30,40)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[42,52)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[20,30)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[30,40)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[42,52)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[20,30)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[30,40)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[42,52)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|mixed|[20,30)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|mixed|[30,40)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|mixed|[42,52)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[20,30)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[30,40)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[42,52)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[20,30)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[30,40)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[42,52)|0 / 0|0|0|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=WARNING pass=0 fail=0 warning=2 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 0, 'FAIL': 0, 'WARNING': 2}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=0 result_seq=0 kind=scope_final phase=0 metric=e2e_bw unit=GB/s start_ticks=0 end_ticks=0 actual=UNAVAILABLE has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=0 duration_ticks=0 bytes_complete=0 events_complete=0 first_known=0 last_known=0 tail_known=0 duration_valid=0 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=0 S=0 samples=0 first_sample_ticks=0 last_sample_ticks=0 sample_span_ticks=0 mean_gbps=0 interval_known=0 coverage_complete=0 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=NO_QUALIFIED_SAMPLES stddev_reason=NO_QUALIFIED_SAMPLES cv_reason=NO_QUALIFIED_SAMPLES excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/no_episode_ns/expect.cfg min_line=4 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=NO_EPISODE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=0 result_seq=0 kind=scope_final phase=0 metric=e2e_bw unit=GB/s start_ticks=0 end_ticks=0 actual=UNAVAILABLE has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=0 events=0 duration_ticks=0 bytes_complete=0 events_complete=0 first_known=0 last_known=0 tail_known=0 duration_valid=0 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=0 S=0 samples=0 first_sample_ticks=0 last_sample_ticks=0 sample_span_ticks=0 mean_gbps=0 interval_known=0 coverage_complete=0 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=NO_QUALIFIED_SAMPLES stddev_reason=NO_QUALIFIED_SAMPLES cv_reason=NO_QUALIFIED_SAMPLES excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/no_episode_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=NO_EPISODE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
