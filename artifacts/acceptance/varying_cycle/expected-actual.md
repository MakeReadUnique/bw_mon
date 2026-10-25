# varying / cycle expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 5744 raw records, 5744 receipts and 2864 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 176, 'variations': 192}.

Configuration: W=20, S=2, Q=24 in cycle; N=3, span=4, K=2. Physical time quantum1fs; end=180000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[22.5,32.5)|640 / 20|64|64|0|1 / 1 / 1 / 0|
|p0|[40.5,50.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[65.5,75.5)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p0|[90.5,100.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[128.5,138.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[22.5,32.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[40.5,50.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[65.5,75.5)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p1|[90.5,100.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[128.5,138.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[22.5,32.5)|640 / 20|64|64|0|1 / 1 / 1 / 0|
|p2|[40.5,50.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[65.5,75.5)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p2|[90.5,100.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[128.5,138.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[22.5,32.5)|3840 / 80|384|384|0|1 / 1 / 1 / 0|
|die0|[40.5,50.5)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[65.5,75.5)|2560 / 40|256|256|0|1 / 1 / 1 / 0|
|die0|[90.5,100.5)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[128.5,138.5)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[22.5,32.5)|7680 / 160|768|768|0|1 / 1 / 1 / 0|
|all_dmc|[40.5,50.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[65.5,75.5)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[90.5,100.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[128.5,138.5)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[22.5,32.5)|5760 / 120|576|576|0|1 / 1 / 1 / 0|
|mixed|[40.5,50.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[65.5,75.5)|3840 / 60|384|384|0|1 / 1 / 1 / 0|
|mixed|[90.5,100.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[128.5,138.5)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|p10|[22.5,32.5)|640 / 20|64|64|0|1 / 1 / 1 / 0|
|p10|[40.5,50.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[65.5,75.5)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p10|[90.5,100.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[128.5,138.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[22.5,32.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[40.5,50.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[65.5,75.5)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p11|[90.5,100.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[128.5,138.5)|1280 / 20|128|128|0|1 / 1 / 1 / 0|

## Episodes and final intervals

|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|
|---|---|---|---:|---:|---:|---|
|p0|0 / 1|20 / 139.5 / 140 / 152|11072 / 188|92.2666666667|92.2666666667|status2; bytes1, events1, member0|
|die0|0 / 1|20 / 139.5 / 140 / 152|46208 / 752|385.066666667|385.066666667|status2; bytes1, events1, member0|
|all_dmc|0 / 1|20 / 139.5 / 140 / 152|92416 / 1504|770.133333333|770.133333333|status2; bytes1, events1, member0|
|mixed|0 / 1|20 / 139.5 / 140 / 152|69312 / 1128|577.6|577.6|status2; bytes1, events1, member0|

Status2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.

## Confirmed fragments (point0 and all_dmc)

|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|
|---|---|---|---:|---:|---|
|p0 / 1|RAMP|[31.5,36.5) / 32.5|115.2|115.2|5 / 72.0 / 11.313708498984761 / 15.713484026367723|
|p0 / 1|STEADY|[47.5,62.5) / 48.5|119.466666667|119.46666666666667|15 / 127.57333333333334 / 1.5964404850235483 / 1.2513904303591776|
|p0 / 1|FALL|[62.5,72.5) / 63.5|64|64|10 / 87.04 / 17.456872572141894 / 20.056149554390963|
|p0 / 1|STEADY|[72.5,81.5) / 73.5|49.7777777778|49.777777777777779|9 / 63.28888888888889 / 2.0113259553750686 / 3.178008005332798|
|p0 / 1|FALL|[81.5,88.5) / 82.5|9.14285714286|9.1428571428571423|7 / 32.0 / 12.8 / 40.0|
|p0 / 1|RAMP|[91.5,98.5) / 92.5|128|128|7 / 83.2 / 25.6 / 30.769230769230766|
|p0 / 1|STEADY|[100.5,110.5) / 101.5|115.2|115.2|10 / 127.36 / 1.92 / 1.5075376884422111|
|p0 / 1|FALL|[110.5,120.5) / 111.5|64|64|10 / 87.04 / 17.456872572141894 / 20.056149554390963|
|p0 / 1|STEADY|[120.5,126.5) / 121.5|85.3333333333|85.333333333333329|6 / 65.06666666666666 / 2.3851391759997758 / 3.665685209016049|
|p0 / 1|RAMP|[126.5,136.5) / 127.5|128|128|10 / 104.96 / 17.456872572141894 / 16.63192889876324|
|p0 / 1|STEADY|[136.5,140) / 137.5|128|128|4 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|RAMP|[32.5,36.5) / 33.5|988|988|4 / 816.0 / 35.77708763999664 / 4.3844470147054695|
|all_dmc / 1|STEADY|[47.5,62.5) / 48.5|955.733333333|955.73333333333335|15 / 1020.5866666666667 / 12.771523880188386 / 1.2513904303591776|
|all_dmc / 1|FALL|[62.5,72.5) / 63.5|512|512|10 / 696.32 / 139.65498057713515 / 20.056149554390963|
|all_dmc / 1|STEADY|[72.5,81.5) / 73.5|398.222222222|398.22222222222223|9 / 506.31111111111113 / 16.09060764300055 / 3.178008005332798|
|all_dmc / 1|FALL|[81.5,88.5) / 82.5|73.1428571429|73.142857142857139|7 / 256.0 / 102.4 / 40.0|
|all_dmc / 1|RAMP|[91.5,98.5) / 92.5|1024|1024|7 / 665.6 / 204.8 / 30.769230769230766|
|all_dmc / 1|STEADY|[100.5,110.5) / 101.5|921.6|921.60000000000002|10 / 1018.88 / 15.36 / 1.5075376884422111|
|all_dmc / 1|FALL|[110.5,120.5) / 111.5|512|512|10 / 696.32 / 139.65498057713515 / 20.056149554390963|
|all_dmc / 1|STEADY|[120.5,126.5) / 121.5|682.666666667|682.66666666666663|6 / 520.5333333333333 / 19.081113407998206 / 3.665685209016049|
|all_dmc / 1|RAMP|[126.5,136.5) / 127.5|1024|1024|10 / 839.68 / 139.65498057713515 / 16.63192889876324|
|all_dmc / 1|STEADY|[136.5,140) / 137.5|1024|1024|4 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=16 fail=2 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 16, 'FAIL': 2, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=phase phase=1 metric=ramp_time unit=ns start_ticks=31500000 end_ticks=36500000 actual=5 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=576 events=10 duration_ticks=5000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=1 basis=1 W=20 S=2 samples=5 first_sample_ticks=31500000 last_sample_ticks=35500000 sample_span_ticks=4000000 mean_gbps=72 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=5 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=phase phase=1 metric=ramp_time unit=ns start_ticks=32500000 end_ticks=36500000 actual=4 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=3952 events=64 duration_ticks=4000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=1 basis=1 W=20 S=2 samples=4 first_sample_ticks=32500000 last_sample_ticks=35500000 sample_span_ticks=3000000 mean_gbps=816 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=11 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=3 kind=phase phase=3 metric=fall_time unit=ns start_ticks=62500000 end_ticks=72500000 actual=10 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=640 events=10 duration_ticks=10000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=3 phase_result_seq=3 basis=1 W=20 S=2 samples=10 first_sample_ticks=62500000 last_sample_ticks=71500000 sample_span_ticks=9000000 mean_gbps=87.039999999999978 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=6 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=3 kind=phase phase=3 metric=fall_time unit=ns start_ticks=62500000 end_ticks=72500000 actual=10 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=5120 events=80 duration_ticks=10000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=3 phase_result_seq=3 basis=1 W=20 S=2 samples=10 first_sample_ticks=62500000 last_sample_ticks=71500000 sample_span_ticks=9000000 mean_gbps=696.31999999999982 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=12 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=5 kind=phase phase=5 metric=fall_time unit=ns start_ticks=81500000 end_ticks=88500000 actual=7 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=64 events=1 duration_ticks=7000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=3 phase_result_seq=5 basis=1 W=20 S=2 samples=7 first_sample_ticks=81500000 last_sample_ticks=87500000 sample_span_ticks=6000000 mean_gbps=31.999999999999996 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=6 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=5 kind=phase phase=5 metric=fall_time unit=ns start_ticks=81500000 end_ticks=88500000 actual=7 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=512 events=8 duration_ticks=7000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=3 phase_result_seq=5 basis=1 W=20 S=2 samples=7 first_sample_ticks=81500000 last_sample_ticks=87500000 sample_span_ticks=6000000 mean_gbps=255.99999999999997 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=12 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=6 kind=phase phase=6 metric=ramp_time unit=ns start_ticks=91500000 end_ticks=98500000 actual=7 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=896 events=14 duration_ticks=7000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=6 basis=1 W=20 S=2 samples=7 first_sample_ticks=91500000 last_sample_ticks=97500000 sample_span_ticks=6000000 mean_gbps=83.200000000000003 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=5 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=6 kind=phase phase=6 metric=ramp_time unit=ns start_ticks=91500000 end_ticks=98500000 actual=7 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=7168 events=112 duration_ticks=7000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=6 basis=1 W=20 S=2 samples=7 first_sample_ticks=91500000 last_sample_ticks=97500000 sample_span_ticks=6000000 mean_gbps=665.60000000000002 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=11 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=8 kind=phase phase=8 metric=fall_time unit=ns start_ticks=110500000 end_ticks=120500000 actual=10 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=640 events=10 duration_ticks=10000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=3 phase_result_seq=8 basis=1 W=20 S=2 samples=10 first_sample_ticks=110500000 last_sample_ticks=119500000 sample_span_ticks=9000000 mean_gbps=87.039999999999978 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=6 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=8 kind=phase phase=8 metric=fall_time unit=ns start_ticks=110500000 end_ticks=120500000 actual=10 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=5120 events=80 duration_ticks=10000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=3 phase_result_seq=8 basis=1 W=20 S=2 samples=10 first_sample_ticks=110500000 last_sample_ticks=119500000 sample_span_ticks=9000000 mean_gbps=696.31999999999982 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=12 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=10 kind=phase phase=10 metric=ramp_time unit=ns start_ticks=126500000 end_ticks=136500000 actual=10 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=1280 events=20 duration_ticks=10000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=10 basis=1 W=20 S=2 samples=10 first_sample_ticks=126500000 last_sample_ticks=135500000 sample_span_ticks=9000000 mean_gbps=104.96000000000002 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=5 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=10 kind=phase phase=10 metric=ramp_time unit=ns start_ticks=126500000 end_ticks=136500000 actual=10 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=10240 events=160 duration_ticks=10000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=10 basis=1 W=20 S=2 samples=10 first_sample_ticks=126500000 last_sample_ticks=135500000 sample_span_ticks=9000000 mean_gbps=839.68000000000018 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=11 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=20000000 end_ticks=140000000 actual=92.266666666666666 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=11072 events=188 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=120 first_sample_ticks=20500000 last_sample_ticks=139500000 sample_span_ticks=119000000 mean_gbps=86.933333333333294 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=20000000 end_ticks=140000000 actual=44.488667661585318 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=11072 events=188 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=120 first_sample_ticks=20500000 last_sample_ticks=139500000 sample_span_ticks=119000000 mean_gbps=86.933333333333294 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=4 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=0 scope=p0 epoch=0 episode=1 result_seq=1 kind=last_steady phase=11 metric=steady_bw unit=GB/s start_ticks=136500000 end_ticks=140000000 actual=128 has_min=1 min=128 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=128 effective_max=0 bytes=448 events=7 duration_ticks=3500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=11 basis=1 W=20 S=2 samples=4 first_sample_ticks=136500000 last_sample_ticks=139500000 sample_span_ticks=3000000 mean_gbps=128 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=3 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=20000000 end_ticks=140000000 actual=770.13333333333333 has_min=1 min=0 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=0 bytes=92416 events=1504 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=120 first_sample_ticks=20500000 last_sample_ticks=139500000 sample_span_ticks=119000000 mean_gbps=727.46666666666636 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=20000000 end_ticks=140000000 actual=39.362439090880237 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=92416 events=1504 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=1 W=20 S=2 samples=120 first_sample_ticks=20500000 last_sample_ticks=139500000 sample_span_ticks=119000000 mean_gbps=727.46666666666636 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=0 max_line=10 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=all_dmc epoch=0 episode=1 result_seq=1 kind=last_steady phase=11 metric=steady_bw unit=GB/s start_ticks=136500000 end_ticks=140000000 actual=1024 has_min=1 min=1024 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=1024 effective_max=0 bytes=3584 events=56 duration_ticks=3500000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=11 basis=1 W=20 S=2 samples=4 first_sample_ticks=136500000 last_sample_ticks=139500000 sample_span_ticks=3000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_cycle/expect.cfg min_line=9 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
