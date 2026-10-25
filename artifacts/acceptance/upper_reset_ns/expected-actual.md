# upper_reset / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 5104 raw records, 5104 receipts and 2558 public windows match the stimulus-only reference. Analysis checks: {'episodes': 17, 'phases': 17, 'variations': 34}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=160000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[94,104)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[95,105)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[105,115)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[94,104)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[95,105)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[105,115)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[94,104)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[95,105)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[105,115)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[94,104)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[95,105)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[105,115)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[104.1,105.1)|1024 / 16|1024|1024|0|0 / 1 / 1 / 0|
|all_dmc|[105.1,115.1)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[94,104)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[95,105)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
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
|p0|0 / 1|0.5 / 119.5 / 120 / 132|15296 / 239|128|128|status2; bytes1, events1, member0|
|die0|0 / 1|0.5 / 119.5 / 120 / 132|61184 / 956|512|512|status2; bytes1, events1, member0|
|all_dmc|0 / 1|0.5 / 103.5 / UNKNOWN / 103.9|105984 / 1656|UNAVAILABLE|UNAVAILABLE|status3; bytes1, events1, member0|
|all_dmc|1 / 2|104.5 / 119.5 / 120 / 132|15872 / 248|1024|1024|status2; bytes1, events1, member0|
|mixed|0 / 1|0.5 / 119.5 / 120 / 132|91776 / 1434|768|768|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[13,120) / 14|128|128|107 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[13,103.9) / 14 END UNKNOWN|UNAVAILABLE|UNAVAILABLE|91 / 1024.0 / 0.0 / 0.0|
|all_dmc / 2|STEADY|[116.1,120) / 117.1|918.974358974|918.97435897435901|4 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=3 fail=2 warning=3 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 3, 'FAIL': 2, 'WARNING': 3}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=0 actual=UNAVAILABLE has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=105984 events=1656 duration_ticks=0 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=0 duration_valid=0 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=94 first_sample_ticks=10000000 last_sample_ticks=103000000 sample_span_ticks=93000000 mean_gbps=1023.4553191489363 interval_known=0 coverage_complete=1 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=RESET_INTERRUPTED stddev_reason=RESET_INTERRUPTED cv_reason=RESET_INTERRUPTED excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=RESET_INTERRUPTED
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=500000 end_ticks=0 actual=UNAVAILABLE has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=105984 events=1656 duration_ticks=0 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=0 duration_valid=0 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=94 first_sample_ticks=10000000 last_sample_ticks=103000000 sample_span_ticks=93000000 mean_gbps=1023.4553191489363 interval_known=0 coverage_complete=1 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=RESET_INTERRUPTED stddev_reason=RESET_INTERRUPTED cv_reason=RESET_INTERRUPTED excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=WARNING reason=RESET_INTERRUPTED
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=1 metric=steady_bw unit=GB/s start_ticks=13000000 end_ticks=103900000 actual=UNAVAILABLE has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=93184 events=1456 duration_ticks=0 bytes_complete=1 events_complete=1 first_known=1 last_known=0 tail_known=0 duration_valid=0 member_reset=0 phase_kind=2 phase_result_seq=1 basis=0 W=10 S=1 samples=91 first_sample_ticks=13000000 last_sample_ticks=103000000 sample_span_ticks=90000000 mean_gbps=1024 interval_known=0 coverage_complete=1 minmax_valid=0 stddev_valid=0 cv_valid=0 minmax_reason=RESET_INTERRUPTED stddev_reason=RESET_INTERRUPTED cv_reason=RESET_INTERRUPTED excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=WARNING reason=RESET_INTERRUPTED
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=128 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=15296 events=239 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=127.94181818181819 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=1 episode=2 result_seq=2 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=104500000 end_ticks=120000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=15872 events=248 duration_ticks=15500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=6 first_sample_ticks=114100000 last_sample_ticks=119100000 sample_span_ticks=5000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=1 episode=2 result_seq=2 kind=episode phase=0 metric=episode_cv unit=% start_ticks=104500000 end_ticks=120000000 actual=0 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=15872 events=248 duration_ticks=15500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=6 first_sample_ticks=114100000 last_sample_ticks=119100000 sample_span_ticks=5000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=1 episode=2 result_seq=2 kind=last_steady phase=2 metric=steady_bw unit=GB/s start_ticks=116100000 end_ticks=120000000 actual=918.97435897435901 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=3584 events=56 duration_ticks=3900000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=2 basis=0 W=10 S=1 samples=4 first_sample_ticks=116100000 last_sample_ticks=119100000 sample_span_ticks=3000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=512 has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=61184 events=956 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=511.76727272727277 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
