# truncated / cycle expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 3504 raw records, 3504 receipts and 1744 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 16, 'variations': 32}.

Configuration: W=20, S=2, Q=24 in cycle; N=3, span=4, K=2. Physical time quantum1fs; end=110000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[92.5,102.5)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[92.5,102.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[92.5,102.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|p10|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|0.5 / 109.5 / UNKNOWN / 110|14016 / 219|UNAVAILABLE|UNAVAILABLE|status4; bytes1, events1, member0|
|die0|0 / 1|0.5 / 109.5 / UNKNOWN / 110|56064 / 876|UNAVAILABLE|UNAVAILABLE|status4; bytes1, events1, member0|
|all_dmc|0 / 1|0.5 / 109.5 / UNKNOWN / 110|112128 / 1752|UNAVAILABLE|UNAVAILABLE|status4; bytes1, events1, member0|
|mixed|0 / 1|0.5 / 109.5 / UNKNOWN / 110|84096 / 1314|UNAVAILABLE|UNAVAILABLE|status4; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[12.5,110) / 13.5 END UNKNOWN|UNAVAILABLE|UNAVAILABLE|98 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[12.5,110) / 13.5 END UNKNOWN|UNAVAILABLE|UNAVAILABLE|98 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=WARNING pass=0 fail=0 warning=2 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 0, 'FAIL': 0, 'WARNING': 2}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=0 actual=UNAVAILABLE has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=112128 events=1752 duration_ticks=0 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=0 duration_valid=0 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=100 first_sample_ticks=10500000 last_sample_ticks=109500000 sample_span_ticks=99000000 mean_gbps=1024 interval_known=0 coverage_complete=1 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=OBSERVATION_TRUNCATED stddev_reason=OBSERVATION_TRUNCATED cv_reason=OBSERVATION_TRUNCATED excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/truncated_cycle/expect.cfg min_line=4 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=OBSERVATION_TRUNCATED
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=0 actual=UNAVAILABLE has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=14016 events=219 duration_ticks=0 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=0 duration_valid=0 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=100 first_sample_ticks=10500000 last_sample_ticks=109500000 sample_span_ticks=99000000 mean_gbps=128 interval_known=0 coverage_complete=1 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=OBSERVATION_TRUNCATED stddev_reason=OBSERVATION_TRUNCATED cv_reason=OBSERVATION_TRUNCATED excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/truncated_cycle/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=OBSERVATION_TRUNCATED
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
