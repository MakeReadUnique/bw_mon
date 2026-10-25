# start_stop / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 3184 raw records, 3184 receipts and 1600 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 32, 'variations': 48}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=100000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[10,20)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p0|[11,21)|128 / 2|12.8|12.8|0|1 / 1 / 1 / 0|
|p0|[20,30)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[50,60)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[51,61)|1152 / 18|115.2|115.2|0|1 / 1 / 1 / 0|
|p0|[60,70)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[10,20)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[11,21)|128 / 2|12.8|12.8|0|1 / 1 / 1 / 0|
|p1|[20,30)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[50,60)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[51,61)|1152 / 18|115.2|115.2|0|1 / 1 / 1 / 0|
|p1|[60,70)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[10,20)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[11,21)|128 / 2|12.8|12.8|0|1 / 1 / 1 / 0|
|p2|[20,30)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[50,60)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[51,61)|1152 / 18|115.2|115.2|0|1 / 1 / 1 / 0|
|p2|[60,70)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[10,20)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[11,21)|512 / 8|51.2|51.2|0|1 / 1 / 1 / 0|
|die0|[20,30)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[50,60)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[51,61)|4608 / 72|460.8|460.8|0|1 / 1 / 1 / 0|
|die0|[60,70)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[10,20)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[11,21)|1024 / 16|102.4|102.4|0|1 / 1 / 1 / 0|
|all_dmc|[20,30)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[50,60)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[51,61)|9216 / 144|921.6|921.6|0|1 / 1 / 1 / 0|
|all_dmc|[60,70)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|mixed|[10,20)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|mixed|[11,21)|768 / 12|76.8|76.8|0|1 / 1 / 1 / 0|
|mixed|[20,30)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[50,60)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[51,61)|6912 / 108|691.2|691.2|0|1 / 1 / 1 / 0|
|mixed|[60,70)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[10,20)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[11,21)|128 / 2|12.8|12.8|0|1 / 1 / 1 / 0|
|p10|[20,30)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[50,60)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[51,61)|1152 / 18|115.2|115.2|0|1 / 1 / 1 / 0|
|p10|[60,70)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[10,20)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[11,21)|128 / 2|12.8|12.8|0|1 / 1 / 1 / 0|
|p11|[20,30)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[50,60)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[51,61)|1152 / 18|115.2|115.2|0|1 / 1 / 1 / 0|
|p11|[60,70)|0 / 0|0|0|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|20 / 59.5 / 60 / 72|5120 / 80|128|128|status2; bytes1, events1, member0|
|die0|0 / 1|20 / 59.5 / 60 / 72|20480 / 320|512|512|status2; bytes1, events1, member0|
|all_dmc|0 / 1|20 / 59.5 / 60 / 72|40960 / 640|1024|1024|status2; bytes1, events1, member0|
|mixed|0 / 1|20 / 59.5 / 60 / 72|30720 / 480|768|768|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|RAMP|[23,32) / 24|128|128|9 / 88.17777777777778 / 31.029225570519365 / 35.189393918179725|
|p0 / 1|STEADY|[32,60) / 33|128|128|28 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|RAMP|[23,32) / 24|1024|1024|9 / 705.4222222222222 / 248.23380456415492 / 35.189393918179725|
|all_dmc / 1|STEADY|[32,60) / 33|1024|1024|28 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=3 fail=2 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 3, 'FAIL': 2, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=20000000 end_ticks=60000000 actual=128 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=5120 events=80 duration_ticks=40000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=39 first_sample_ticks=21000000 last_sample_ticks=59000000 sample_span_ticks=38000000 mean_gbps=113.23076923076921 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/start_stop_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=20000000 end_ticks=60000000 actual=512 has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=20480 events=320 duration_ticks=40000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=39 first_sample_ticks=21000000 last_sample_ticks=59000000 sample_span_ticks=38000000 mean_gbps=452.92307692307685 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/start_stop_ns/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=20000000 end_ticks=60000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=40960 events=640 duration_ticks=40000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=39 first_sample_ticks=21000000 last_sample_ticks=59000000 sample_span_ticks=38000000 mean_gbps=905.8461538461537 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/start_stop_ns/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=20000000 end_ticks=60000000 actual=27.635214925340364 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=40960 events=640 duration_ticks=40000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=39 first_sample_ticks=21000000 last_sample_ticks=59000000 sample_span_ticks=38000000 mean_gbps=905.8461538461537 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/start_stop_ns/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=2 metric=steady_bw unit=GB/s start_ticks=32000000 end_ticks=60000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=28672 events=448 duration_ticks=28000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=2 basis=0 W=10 S=1 samples=28 first_sample_ticks=32000000 last_sample_ticks=59000000 sample_span_ticks=27000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/start_stop_ns/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
