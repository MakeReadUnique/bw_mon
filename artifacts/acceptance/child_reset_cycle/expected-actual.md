# child_reset / cycle expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 5104 raw records, 5104 receipts and 2543 public windows match the stimulus-only reference. Analysis checks: {'episodes': 17, 'phases': 17, 'variations': 34}.

Configuration: W=20, S=2, Q=24 in cycle; N=3, span=4, K=2. Physical time quantum1fs; end=160000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[94.5,104.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[95.5,105.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[105.5,115.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[94.5,104.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[95.5,105.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[105.5,115.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[94.5,104.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[95.5,105.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[105.5,115.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[104.5,105.5)|512 / 8|512|512|0|0 / 1 / 1 / 0|
|die0|[105.5,115.5)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[94.5,104.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[95.5,105.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[105.5,115.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[94.5,104.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[95.5,105.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[105.5,115.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|p10|[94.5,104.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[95.5,105.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[105.5,115.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[94.5,104.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[95.5,105.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[105.5,115.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|0.5 / 119.5 / 120 / 132|15296 / 239|128|128|status2; bytes1, events1, member0|
|die0|0 / 1|0.5 / 103.5 / UNKNOWN / 103.9|52992 / 828|UNAVAILABLE|UNAVAILABLE|status3; bytes1, events1, member0|
|die0|1 / 2|104.5 / 119.5 / 120 / 132|7936 / 124|512|512|status2; bytes1, events1, member0|
|all_dmc|0 / 1|0.5 / 119.5 / 120 / 132|122368 / 1912|1024|1024|status2; bytes1, events1, member0|
|mixed|0 / 1|0.5 / 119.5 / 120 / 132|91776 / 1434|768|768|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[12.5,120) / 13.5|128|128|108 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[12.5,120) / 13.5|1024|1024|108 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=4 fail=1 warning=1 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 4, 'FAIL': 1, 'WARNING': 1}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=0 actual=UNAVAILABLE has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=52992 events=828 duration_ticks=0 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=0 duration_valid=0 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=94 first_sample_ticks=10500000 last_sample_ticks=103500000 sample_span_ticks=93000000 mean_gbps=512 interval_known=0 coverage_complete=1 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=RESET_INTERRUPTED stddev_reason=RESET_INTERRUPTED cv_reason=RESET_INTERRUPTED excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/child_reset_cycle/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=RESET_INTERRUPTED
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=128 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=15296 events=239 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=110 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=128 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/child_reset_cycle/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=122368 events=1912 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=110 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/child_reset_cycle/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=500000 end_ticks=120000000 actual=0 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=122368 events=1912 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=110 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/child_reset_cycle/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=1 metric=steady_bw unit=GB/s start_ticks=12500000 end_ticks=120000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=110080 events=1720 duration_ticks=107500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=1 basis=1 W=20 S=2 samples=108 first_sample_ticks=12500000 last_sample_ticks=119500000 sample_span_ticks=107000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/child_reset_cycle/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=1 episode=2 result_seq=2 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=104500000 end_ticks=120000000 actual=512 has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=7936 events=124 duration_ticks=15500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=6 first_sample_ticks=114500000 last_sample_ticks=119500000 sample_span_ticks=5000000 mean_gbps=512 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/child_reset_cycle/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
