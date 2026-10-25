# frequency / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 3824 raw records, 3824 receipts and 2560 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 48, 'variations': 64}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=160000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[75,85)|960 / 15|96|96|0|1 / 1 / 1 / 0|
|p0|[81,91)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p0|[92,102)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p1|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[75,85)|960 / 15|96|96|0|1 / 1 / 1 / 0|
|p1|[81,91)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p1|[92,102)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p2|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[75,85)|960 / 15|96|96|0|1 / 1 / 1 / 0|
|p2|[81,91)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p2|[92,102)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|die0|[69,79)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[75,85)|3840 / 60|384|384|0|1 / 1 / 1 / 0|
|die0|[81,91)|2560 / 40|256|256|0|1 / 1 / 1 / 0|
|die0|[92,102)|2560 / 40|256|256|0|1 / 1 / 1 / 0|
|all_dmc|[69,79)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[75,85)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|all_dmc|[81,91)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[92,102)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|mixed|[69,79)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[75,85)|5760 / 90|576|576|0|1 / 1 / 1 / 0|
|mixed|[81,91)|3840 / 60|384|384|0|1 / 1 / 1 / 0|
|mixed|[92,102)|3840 / 60|384|384|0|1 / 1 / 1 / 0|
|p10|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[75,85)|960 / 15|96|96|0|1 / 1 / 1 / 0|
|p10|[81,91)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p10|[92,102)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p11|[69,79)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[75,85)|960 / 15|96|96|0|1 / 1 / 1 / 0|
|p11|[81,91)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p11|[92,102)|640 / 10|64|64|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|0.5 / 119.5 / 120.5 / 132.5|12736 / 199|106.133333333|106.133333333|status2; bytes1, events1, member0|
|die0|0 / 1|0.5 / 119.5 / 120.5 / 132.5|50944 / 796|424.533333333|424.533333333|status2; bytes1, events1, member0|
|all_dmc|0 / 1|0.5 / 119.5 / 120.5 / 132.5|101888 / 1592|849.066666667|849.066666667|status2; bytes1, events1, member0|
|mixed|0 / 1|0.5 / 119.5 / 120.5 / 132.5|76416 / 1194|636.8|636.8|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[13,82) / 14|126.144927536|126.14492753623189|69 / 127.9072463768116 / 0.7648659711290733 / 0.5979848623085803|
|p0 / 1|FALL|[82,92) / 83|64|64|10 / 87.04 / 17.456872572141894 / 20.056149554390963|
|p0 / 1|STEADY|[92,120.5) / 93|62.8771929825|62.877192982456137|29 / 64.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[13,82) / 14|1009.15942029|1009.1594202898551|69 / 1023.2579710144928 / 6.118927769032586 / 0.5979848623085803|
|all_dmc / 1|FALL|[82,92) / 83|512|512|10 / 696.32 / 139.65498057713515 / 20.056149554390963|
|all_dmc / 1|STEADY|[92,120.5) / 93|503.01754386|503.01754385964909|29 / 512.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=0 fail=5 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 0, 'FAIL': 5, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120500000 actual=106.13333333333334 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=12736 events=199 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=111 first_sample_ticks=10000000 last_sample_ticks=120000000 sample_span_ticks=110000000 mean_gbps=107.4738738738739 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120500000 actual=849.06666666666672 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=101888 events=1592 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=111 first_sample_ticks=10000000 last_sample_ticks=120000000 sample_span_ticks=110000000 mean_gbps=859.79099099099119 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_ns/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=500000 end_ticks=120500000 actual=26.776244983203707 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=101888 events=1592 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=111 first_sample_ticks=10000000 last_sample_ticks=120000000 sample_span_ticks=110000000 mean_gbps=859.79099099099119 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_ns/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=3 metric=steady_bw unit=GB/s start_ticks=92000000 end_ticks=120500000 actual=503.01754385964909 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=14336 events=224 duration_ticks=28500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=3 basis=0 W=10 S=1 samples=29 first_sample_ticks=92000000 last_sample_ticks=120000000 sample_span_ticks=28000000 mean_gbps=512 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_ns/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120500000 actual=424.53333333333336 has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=50944 events=796 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=111 first_sample_ticks=10000000 last_sample_ticks=120000000 sample_span_ticks=110000000 mean_gbps=429.8954954954956 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_ns/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
