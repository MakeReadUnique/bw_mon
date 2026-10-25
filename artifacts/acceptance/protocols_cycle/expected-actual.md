# protocols / cycle expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 5104 raw records, 5104 receipts and 2544 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 32, 'variations': 48}.

Configuration: W=20, S=2, Q=24 in cycle; N=3, span=4, K=2. Physical time quantum1fs; end=160000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[51.5,61.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[55.5,65.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[51.5,61.5)|1088 / 17|108.8|108.8|0|1 / 1 / 1 / 0|
|p1|[55.5,65.5)|768 / 12|76.8|76.8|0|1 / 1 / 1 / 0|
|p1|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[51.5,61.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[55.5,65.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[51.5,61.5)|4928 / 77|492.8|492.8|0|1 / 1 / 1 / 0|
|die0|[55.5,65.5)|4608 / 72|460.8|460.8|0|1 / 1 / 1 / 0|
|die0|[92.5,102.5)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[51.5,61.5)|10048 / 157|1004.8|1004.8|0|1 / 1 / 1 / 0|
|all_dmc|[55.5,65.5)|9728 / 152|972.8|972.8|0|1 / 1 / 1 / 0|
|all_dmc|[92.5,102.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[51.5,61.5)|7488 / 117|748.8|748.8|0|1 / 1 / 1 / 0|
|mixed|[55.5,65.5)|7168 / 112|716.8|716.8|0|1 / 1 / 1 / 0|
|mixed|[92.5,102.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|p10|[51.5,61.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[55.5,65.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[51.5,61.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[55.5,65.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[92.5,102.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|0.5 / 119.5 / 120 / 132|15296 / 239|128|128|status2; bytes1, events1, member0|
|die0|0 / 1|0.5 / 119.5 / 120 / 132|60672 / 948|507.715481172|507.715481172|status2; bytes1, events1, member0|
|all_dmc|0 / 1|0.5 / 119.5 / 120 / 132|121856 / 1904|1019.71548117|1019.71548117|status2; bytes1, events1, member0|
|mixed|0 / 1|0.5 / 119.5 / 120 / 132|91264 / 1426|763.715481172|763.715481172|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|STEADY|[12.5,120) / 13.5|128|128|108 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[12.5,60.5) / 13.5|1022.66666667|1022.6666666666666|48 / 1024.0 / 0.0 / 0.0|
|all_dmc / 1|FALL|[62.5,64.5) / 63.5|928|928|2 / 985.6 / 6.4 / 0.6493506493506493|
|all_dmc / 1|STEADY|[66.5,70.5) / 67.5|1024|1024|4 / 972.8 / 0.0 / 0.0|
|all_dmc / 1|RAMP|[72.5,74.5) / 73.5|1024|1024|2 / 1011.2 / 6.4 / 0.6329113924050632|
|all_dmc / 1|STEADY|[76.5,120) / 77.5|1024|1024|44 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=2 fail=3 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 2, 'FAIL': 3, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=128 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=15296 events=239 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=110 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=128 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_cycle/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=1019.7154811715482 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=121856 events=1904 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=110 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=1019.3454545454547 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_cycle/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=500000 end_ticks=120000000 actual=1.3302883225531692 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=121856 events=1904 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=110 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=1019.3454545454547 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_cycle/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=5 metric=steady_bw unit=GB/s start_ticks=76500000 end_ticks=120000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=44544 events=696 duration_ticks=43500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=5 basis=1 W=20 S=2 samples=44 first_sample_ticks=76500000 last_sample_ticks=119500000 sample_span_ticks=43000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_cycle/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=507.71548117154811 has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=60672 events=948 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=110 first_sample_ticks=10500000 last_sample_ticks=119500000 sample_span_ticks=109000000 mean_gbps=507.34545454545452 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_cycle/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
