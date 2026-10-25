# e4_below / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 2064 raw records, 2064 receipts and 2080 public windows match the stimulus-only reference. Analysis checks: {'episodes': 4, 'phases': 12, 'variations': 16}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=130000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[92,102)|1368 / 9|136.8|136.8|0|1 / 1 / 1 / 0|
|p1|[92,102)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[92,102)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[92,102)|1368 / 9|136.8|136.8|0|1 / 1 / 1 / 0|
|all_dmc|[92,102)|1368 / 9|136.8|136.8|0|1 / 1 / 1 / 0|
|mixed|[92,102)|1368 / 9|136.8|136.8|0|1 / 1 / 1 / 0|
|p10|[92,102)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[92,102)|0 / 0|0|0|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|1 / 100 / 101 / 113|15199 / 100|151.99|151.99|status2; bytes1, events1, member0|
|die0|0 / 1|1 / 100 / 101 / 113|15199 / 100|151.99|151.99|status2; bytes1, events1, member0|
|all_dmc|0 / 1|1 / 100 / 101 / 113|15199 / 100|151.99|151.99|status2; bytes1, events1, member0|
|mixed|0 / 1|1 / 100 / 101 / 113|15199 / 100|151.99|151.99|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[13,51) / 14|151.973684211|151.97368421052633|38 / 152.0 / 0.0 / 0.0|
|p0 / 1|STEADY|[53,61) / 54|152|152|8 / 151.9 / 0.0 / 0.0|
|p0 / 1|STEADY|[63,101) / 64|152|152|38 / 152.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[13,51) / 14|151.973684211|151.97368421052633|38 / 152.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[53,61) / 54|152|152|8 / 151.9 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[63,101) / 64|152|152|38 / 152.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=0 fail=1 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 0, 'FAIL': 1, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=1000000 end_ticks=101000000 actual=151.99000000000001 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=15199 events=100 duration_ticks=100000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=91 first_sample_ticks=10000000 last_sample_ticks=100000000 sample_span_ticks=90000000 mean_gbps=151.82197802197808 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=8 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e4_below_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
