# frequency / cycle expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 3824 raw records, 3824 receipts and 1904 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 32, 'variations': 48}.

Configuration: W=20, S=2, Q=24 in cycle; N=3, span=4, K=2. Physical time quantum1fs; end=160000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[69.5,79.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[72.5,85.5)|1280 / 20|98.4615384615|98.4615384615|0|1 / 1 / 1 / 0|
|p0|[75.5,91.5)|1280 / 20|80|80|0|1 / 1 / 1 / 0|
|p0|[83.5,103.5)|1280 / 20|64|64|0|1 / 1 / 1 / 0|
|p1|[69.5,79.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[72.5,85.5)|1280 / 20|98.4615384615|98.4615384615|0|1 / 1 / 1 / 0|
|p1|[75.5,91.5)|1280 / 20|80|80|0|1 / 1 / 1 / 0|
|p1|[83.5,103.5)|1280 / 20|64|64|0|1 / 1 / 1 / 0|
|p2|[69.5,79.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[72.5,85.5)|1280 / 20|98.4615384615|98.4615384615|0|1 / 1 / 1 / 0|
|p2|[75.5,91.5)|1280 / 20|80|80|0|1 / 1 / 1 / 0|
|p2|[83.5,103.5)|1280 / 20|64|64|0|1 / 1 / 1 / 0|
|die0|[69.5,79.5)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[72.5,85.5)|5120 / 80|393.846153846|393.846153846|0|1 / 1 / 1 / 0|
|die0|[75.5,91.5)|5120 / 80|320|320|0|1 / 1 / 1 / 0|
|die0|[83.5,103.5)|5120 / 80|256|256|0|1 / 1 / 1 / 0|
|all_dmc|[69.5,79.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[72.5,85.5)|10240 / 160|787.692307692|787.692307692|0|1 / 1 / 1 / 0|
|all_dmc|[75.5,91.5)|10240 / 160|640|640|0|1 / 1 / 1 / 0|
|all_dmc|[83.5,103.5)|10240 / 160|512|512|0|1 / 1 / 1 / 0|
|mixed|[69.5,79.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[72.5,85.5)|7680 / 120|590.769230769|590.769230769|0|1 / 1 / 1 / 0|
|mixed|[75.5,91.5)|7680 / 120|480|480|0|1 / 1 / 1 / 0|
|mixed|[83.5,103.5)|7680 / 120|384|384|0|1 / 1 / 1 / 0|
|p10|[69.5,79.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[72.5,85.5)|1280 / 20|98.4615384615|98.4615384615|0|1 / 1 / 1 / 0|
|p10|[75.5,91.5)|1280 / 20|80|80|0|1 / 1 / 1 / 0|
|p10|[83.5,103.5)|1280 / 20|64|64|0|1 / 1 / 1 / 0|
|p11|[69.5,79.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[72.5,85.5)|1280 / 20|98.4615384615|98.4615384615|0|1 / 1 / 1 / 0|
|p11|[75.5,91.5)|1280 / 20|80|80|0|1 / 1 / 1 / 0|
|p11|[83.5,103.5)|1280 / 20|64|64|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|0.5 / 119.5 / 120.5 / 144.5|12736 / 199|106.133333333|106.133333333|status2; bytes1, events1, member0|
|die0|0 / 1|0.5 / 119.5 / 120.5 / 144.5|50944 / 796|424.533333333|424.533333333|status2; bytes1, events1, member0|
|all_dmc|0 / 1|0.5 / 119.5 / 120.5 / 144.5|101888 / 1592|849.066666667|849.066666667|status2; bytes1, events1, member0|
|mixed|0 / 1|0.5 / 119.5 / 120.5 / 144.5|76416 / 1194|636.8|636.8|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[12.5,81.5) / 13.5|126.144927536|126.14492753623189|68 / 128.0 / 0.0 / 0.0|
|p0 / 1|STEADY|[103.5,120.5) / 105.5|64|64|9 / 64.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[12.5,81.5) / 13.5|1009.15942029|1009.1594202898551|68 / 1024.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[103.5,120.5) / 105.5|512|512|9 / 512.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=0 fail=5 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 0, 'FAIL': 5, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120500000 actual=106.13333333333334 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=12736 events=199 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=90 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=116.178082178495 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_cycle/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120500000 actual=849.06666666666672 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=101888 events=1592 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=90 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=929.42465742796003 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_cycle/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=500000 end_ticks=120500000 actual=20.103200496029771 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=101888 events=1592 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=90 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=929.42465742796003 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_cycle/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=2 metric=steady_bw unit=GB/s start_ticks=103500000 end_ticks=120500000 actual=512 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=8704 events=136 duration_ticks=17000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=2 basis=1 W=20 S=2 samples=9 first_sample_ticks=103500000 last_sample_ticks=119500000 sample_span_ticks=16000000 mean_gbps=512 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_cycle/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120500000 actual=424.53333333333336 has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=50944 events=796 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=90 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=464.71232871398001 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_cycle/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
