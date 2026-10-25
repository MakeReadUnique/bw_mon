# protocols / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 5104 raw records, 5104 receipts and 2560 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 32, 'variations': 48}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=160000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[51,61)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[55,65)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[92,102)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[51,61)|1152 / 18|115.2|115.2|0|1 / 1 / 1 / 0|
|p1|[55,65)|768 / 12|76.8|76.8|0|1 / 1 / 1 / 0|
|p1|[92,102)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[51,61)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[55,65)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[92,102)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[51,61)|4992 / 78|499.2|499.2|0|1 / 1 / 1 / 0|
|die0|[55,65)|4608 / 72|460.8|460.8|0|1 / 1 / 1 / 0|
|die0|[92,102)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[51,61)|10112 / 158|1011.2|1011.2|0|1 / 1 / 1 / 0|
|all_dmc|[55,65)|9728 / 152|972.8|972.8|0|1 / 1 / 1 / 0|
|all_dmc|[92,102)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[51,61)|7552 / 118|755.2|755.2|0|1 / 1 / 1 / 0|
|mixed|[55,65)|7168 / 112|716.8|716.8|0|1 / 1 / 1 / 0|
|mixed|[92,102)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|p10|[51,61)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[55,65)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[92,102)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[51,61)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[55,65)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[92,102)|1280 / 20|128|128|0|1 / 1 / 1 / 0|

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
|p0 / 1|STEADY|[13,120) / 14|128|128|107 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|STEADY|[13,62) / 14|1018.7755102|1018.7755102040817|49 / 1023.738775510204 / 1.8098163540311534 / 0.17678497653165373|
|all_dmc / 1|FALL|[62,66) / 63|960|960|4 / 982.4 / 10.613199329137279 / 1.0803338079333549|
|all_dmc / 1|STEADY|[66,72) / 67|1024|1024|6 / 974.9333333333333 / 4.7702783519995515 / 0.48929277406997596|
|all_dmc / 1|RAMP|[72,76) / 73|1024|1024|4 / 1014.4 / 10.613199329137279 / 1.0462538770837222|
|all_dmc / 1|STEADY|[76,120) / 77|1024|1024|44 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=2 fail=3 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 2, 'FAIL': 3, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=128 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=152 effective_max=0 bytes=15296 events=239 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=127.94181818181819 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=1019.7154811715482 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=121856 events=1904 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=1018.8799999999999 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_ns/expect.cfg min_line=7 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=500000 end_ticks=120000000 actual=1.4091545742519143 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=121856 events=1904 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=1018.8799999999999 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_ns/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=5 metric=steady_bw unit=GB/s start_ticks=76000000 end_ticks=120000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=45056 events=704 duration_ticks=44000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=5 basis=0 W=10 S=1 samples=44 first_sample_ticks=76000000 last_sample_ticks=119000000 sample_span_ticks=43000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_ns/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=die0_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=500000 end_ticks=120000000 actual=507.71548117154811 has_min=1 min=512 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=512 effective_max=0 bytes=60672 events=948 duration_ticks=119500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=110 first_sample_ticks=10000000 last_sample_ticks=119000000 sample_span_ticks=109000000 mean_gbps=507.11272727272723 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=9 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_ns/expect.cfg min_line=5 max_line=0 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
