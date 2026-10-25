# clock_stop / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 4448 raw records, 4448 receipts and 2560 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 80, 'variations': 96}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=160000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[80,90)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p0|[91,101)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p0|[102,112)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[80,90)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p1|[91,101)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p1|[102,112)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[80,90)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p2|[91,101)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p2|[102,112)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[69,79)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[80,90)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|die0|[91,101)|256 / 4|25.6|25.6|0|1 / 1 / 1 / 0|
|die0|[102,112)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[69,79)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[80,90)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|all_dmc|[91,101)|512 / 8|51.2|51.2|0|1 / 1 / 1 / 0|
|all_dmc|[102,112)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[69,79)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[80,90)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|mixed|[91,101)|384 / 6|38.4|38.4|0|1 / 1 / 1 / 0|
|mixed|[102,112)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|p10|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[80,90)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p10|[91,101)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p10|[102,112)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[80,90)|0 / 0|0|0|0|1 / 1 / 1 / 0|
|p11|[91,101)|64 / 1|6.4|6.4|0|1 / 1 / 1 / 0|
|p11|[102,112)|1280 / 20|128|128|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|0.5 / 119.5 / 120 / 132|12672 / 198|106.041841004|106.041841004|status2; bytes1, events1, member0|
|die0|0 / 1|0.5 / 119.5 / 120 / 132|50688 / 792|424.167364017|424.167364017|status2; bytes1, events1, member0|
|all_dmc|0 / 1|0.5 / 119.5 / 120 / 132|101376 / 1584|848.334728033|848.334728033|status2; bytes1, events1, member0|
|mixed|0 / 1|0.5 / 119.5 / 120 / 132|76032 / 1188|636.251046025|636.251046025|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[13,82) / 14|124.289855072|124.28985507246377|69 / 127.81449275362318 / 1.5297319422581466 / 1.196837627174938|
|p0 / 1|FALL|[82,92) / 83|0|0|10 / 46.08 / 34.91374514428379 / 75.76767609436587|
|p0 / 1|STEADY|[92,101) / 93|7.11111111111|7.1111111111111107|9 / 0.0 / 0.0 / None|
|p0 / 1|RAMP|[103,111) / 104|128|128|8 / 76.8 / 29.328484447717376 / 38.18813079129867|
|p0 / 1|STEADY|[113,120) / 114|128|128|7 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[13,82) / 14|994.31884058|994.31884057971013|69 / 1022.5159420289855 / 12.237855538065173 / 1.196837627174938|
|all_dmc / 1|FALL|[82,92) / 83|0|0|10 / 368.64 / 279.3099611542703 / 75.76767609436587|
|all_dmc / 1|STEADY|[92,101) / 93|56.8888888889|56.888888888888886|9 / 0.0 / 0.0 / None|
|all_dmc / 1|RAMP|[103,111) / 104|1024|1024|8 / 614.4 / 234.627875581739 / 38.18813079129867|
|all_dmc / 1|STEADY|[113,120) / 114|1024|1024|7 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=1 fail=4 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 1, 'FAIL': 4, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=106.04184100418411 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=12672 events=198 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=104.08727272727273 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/clock_stop_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=848.33472803347286 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=101376 events=1584 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=832.69818181818187 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/clock_stop_ns/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=500000 end_ticks=120000000 actual=42.82206873685854 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=101376 events=1584 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=832.69818181818187 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/clock_stop_ns/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=5 metric=steady_bw unit=GB/s start_ticks=113000000 end_ticks=120000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=7168 events=112 duration_ticks=7000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=5 basis=0 W=10 S=1 samples=7 first_sample_ticks=113000000 last_sample_ticks=119000000 sample_span_ticks=6000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/clock_stop_ns/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=424.16736401673643 has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=50688 events=792 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=416.34909090909093 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/clock_stop_ns/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
