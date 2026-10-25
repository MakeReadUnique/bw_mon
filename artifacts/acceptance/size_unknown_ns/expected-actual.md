# size_unknown / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 5104 raw records, 5104 receipts and 2560 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 20, 'variations': 36}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=160000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[94,104)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[95,105)|1216 / 20|121.6|121.6|0|1 / 0 / 1 / 0|
|p0|[105,115)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[94,104)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[95,105)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[105,115)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[94,104)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[95,105)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[105,115)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[94,104)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[95,105)|5056 / 80|505.6|505.6|0|1 / 0 / 1 / 0|
|die0|[105,115)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[94,104)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[95,105)|10176 / 160|1017.6|1017.6|0|1 / 0 / 1 / 0|
|all_dmc|[105,115)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[94,104)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[95,105)|7616 / 120|761.6|761.6|0|1 / 0 / 1 / 0|
|mixed|[105,115)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|p10|[94,104)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[95,105)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[105,115)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[94,104)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[95,105)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[105,115)|1280 / 20|128|128|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|0.5 / 119.5 / 120 / 132|15232 / 239|UNAVAILABLE|UNAVAILABLE|status2; bytes0, events1, member0|
|die0|0 / 1|0.5 / 119.5 / 120 / 132|61120 / 956|UNAVAILABLE|UNAVAILABLE|status2; bytes0, events1, member0|
|all_dmc|0 / 1|0.5 / 119.5 / 120 / 132|122304 / 1912|UNAVAILABLE|UNAVAILABLE|status2; bytes0, events1, member0|
|mixed|0 / 1|0.5 / 119.5 / 120 / 132|91712 / 1434|UNAVAILABLE|UNAVAILABLE|status2; bytes0, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[13,105) / 14|UNAVAILABLE|UNAVAILABLE|92 / 128.0 / 0.0 / 0.0|
|p0 / 1|STEADY|[117,120) / 118|128|128|3 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[13,105) / 14|UNAVAILABLE|UNAVAILABLE|92 / 1024.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[117,120) / 118|1024|1024|3 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=WARNING pass=1 fail=0 warning=4 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 1, 'FAIL': 0, 'WARNING': 4}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=UNAVAILABLE has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=15232 events=239 duration_ticks=119500000 bytes_complete=0 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=100 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=127.93600000000002 interval_known=1 coverage_complete=0 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=OBSERVATION_INCOMPLETE stddev_reason=OBSERVATION_INCOMPLETE cv_reason=OBSERVATION_INCOMPLETE excluded_warmup=9 excluded_foreign=0 unknown_samples=10 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/size_unknown_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=WARNING reason=BYTES_INCOMPLETE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=UNAVAILABLE has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=122304 events=1912 duration_ticks=119500000 bytes_complete=0 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=100 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=1023.4880000000002 interval_known=1 coverage_complete=0 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=OBSERVATION_INCOMPLETE stddev_reason=OBSERVATION_INCOMPLETE cv_reason=OBSERVATION_INCOMPLETE excluded_warmup=9 excluded_foreign=0 unknown_samples=10 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/size_unknown_ns/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=BYTES_INCOMPLETE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=500000 end_ticks=120000000 actual=UNAVAILABLE has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=122304 events=1912 duration_ticks=119500000 bytes_complete=0 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=100 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=1023.4880000000002 interval_known=1 coverage_complete=0 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=OBSERVATION_INCOMPLETE stddev_reason=OBSERVATION_INCOMPLETE cv_reason=OBSERVATION_INCOMPLETE excluded_warmup=9 excluded_foreign=0 unknown_samples=10 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/size_unknown_ns/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=WARNING reason=OBSERVATION_INCOMPLETE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=2 metric=steady_bw unit=GB/s start_ticks=117000000 end_ticks=120000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=3072 events=48 duration_ticks=3000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=2 basis=0 W=10 S=1 samples=3 first_sample_ticks=117000000 last_sample_ticks=119000000 sample_span_ticks=2000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/size_unknown_ns/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=UNAVAILABLE has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=61120 events=956 duration_ticks=119500000 bytes_complete=0 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=100 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=511.74400000000009 interval_known=1 coverage_complete=0 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=OBSERVATION_INCOMPLETE stddev_reason=OBSERVATION_INCOMPLETE cv_reason=OBSERVATION_INCOMPLETE excluded_warmup=9 excluded_foreign=0 unknown_samples=10 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/size_unknown_ns/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=BYTES_INCOMPLETE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
