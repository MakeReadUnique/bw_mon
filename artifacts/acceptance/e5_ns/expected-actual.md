# e5 / ns expected and actual

Automated checks **PASS**. **Human review PENDING**; agent inspection is separate.

All 5744 raw records, 5744 receipts and 2880 public windows match the stimulus-only reference. Analysis checks: {'episodes': 16, 'phases': 176, 'variations': 192}.

Configuration: W=10, S=1, Q=12 in ns; N=3, span=2, K=2. Physical time quantum1fs; end=180000001fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.

## Input and window checkpoints

See [raw stimulus](trace.tar.gz) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.

|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|
|---|---|---:|---:|---:|---:|---|
|p0|[22,32)|600 / 20|60|60|0|1 / 1 / 1 / 0|
|p0|[40,50)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[65,75)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p0|[90,100)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p0|[128,138)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[22,32)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[40,50)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[65,75)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p1|[90,100)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p1|[128,138)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[22,32)|600 / 20|60|60|0|1 / 1 / 1 / 0|
|p2|[40,50)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[65,75)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p2|[90,100)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p2|[128,138)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|die0|[22,32)|3760 / 80|376|376|0|1 / 1 / 1 / 0|
|die0|[40,50)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[65,75)|2560 / 40|256|256|0|1 / 1 / 1 / 0|
|die0|[90,100)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|die0|[128,138)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[22,32)|7520 / 160|752|752|0|1 / 1 / 1 / 0|
|all_dmc|[40,50)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[65,75)|5120 / 80|512|512|0|1 / 1 / 1 / 0|
|all_dmc|[90,100)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|all_dmc|[128,138)|10240 / 160|1024|1024|0|1 / 1 / 1 / 0|
|mixed|[22,32)|5640 / 120|564|564|0|1 / 1 / 1 / 0|
|mixed|[40,50)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[65,75)|3840 / 60|384|384|0|1 / 1 / 1 / 0|
|mixed|[90,100)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|mixed|[128,138)|7680 / 120|768|768|0|1 / 1 / 1 / 0|
|p10|[22,32)|600 / 20|60|60|0|1 / 1 / 1 / 0|
|p10|[40,50)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[65,75)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p10|[90,100)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p10|[128,138)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[22,32)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[40,50)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[65,75)|640 / 10|64|64|0|1 / 1 / 1 / 0|
|p11|[90,100)|1280 / 20|128|128|0|1 / 1 / 1 / 0|
|p11|[128,138)|1280 / 20|128|128|0|1 / 1 / 1 / 0|

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
|p0 / 1|RAMP|[31,37) / 32|114.666666667|114.66666666666667|6 / 72.0 / 13.662601021279464 / 18.975834751777032|
|p0 / 1|STEADY|[47,62) / 48|119.466666667|119.46666666666667|15 / 127.57333333333334 / 1.5964404850235483 / 1.2513904303591776|
|p0 / 1|FALL|[62,72) / 63|64|64|10 / 87.04 / 17.456872572141894 / 20.056149554390963|
|p0 / 1|STEADY|[72,82) / 73|51.2|51.200000000000003|10 / 63.36 / 1.92 / 3.0303030303030303|
|p0 / 1|FALL|[82,92) / 83|51.2|51.200000000000003|10 / 30.72 / 11.73139377908695 / 38.18813079129867|
|p0 / 1|RAMP|[92,100) / 93|128|128|8 / 94.4 / 27.105718953755865 / 28.7136853323685|
|p0 / 1|STEADY|[100,110) / 101|115.2|115.2|10 / 127.36 / 1.92 / 1.5075376884422111|
|p0 / 1|FALL|[110,120) / 111|64|64|10 / 87.04 / 17.456872572141894 / 20.056149554390963|
|p0 / 1|STEADY|[120,126) / 121|85.3333333333|85.333333333333329|6 / 65.06666666666666 / 2.3851391759997758 / 3.665685209016049|
|p0 / 1|RAMP|[126,136) / 127|128|128|10 / 104.96 / 17.456872572141894 / 16.63192889876324|
|p0 / 1|STEADY|[136,140) / 137|128|128|4 / 128.0 / 0.0 / 0.0|
|all_dmc / 1|RAMP|[32,37) / 33|985.6|985.60000000000002|5 / 816.0 / 45.254833995939045 / 5.54593553871802|
|all_dmc / 1|STEADY|[47,62) / 48|955.733333333|955.73333333333335|15 / 1020.5866666666667 / 12.771523880188386 / 1.2513904303591776|
|all_dmc / 1|FALL|[62,72) / 63|512|512|10 / 696.32 / 139.65498057713515 / 20.056149554390963|
|all_dmc / 1|STEADY|[72,82) / 73|409.6|409.60000000000002|10 / 506.88 / 15.36 / 3.0303030303030303|
|all_dmc / 1|FALL|[82,92) / 83|409.6|409.60000000000002|10 / 245.76 / 93.8511502326956 / 38.18813079129867|
|all_dmc / 1|RAMP|[92,100) / 93|1024|1024|8 / 755.2 / 216.84575163004692 / 28.7136853323685|
|all_dmc / 1|STEADY|[100,110) / 101|921.6|921.60000000000002|10 / 1018.88 / 15.36 / 1.5075376884422111|
|all_dmc / 1|FALL|[110,120) / 111|512|512|10 / 696.32 / 139.65498057713515 / 20.056149554390963|
|all_dmc / 1|STEADY|[120,126) / 121|682.666666667|682.66666666666663|6 / 520.5333333333333 / 19.081113407998206 / 3.665685209016049|
|all_dmc / 1|RAMP|[126,136) / 127|1024|1024|10 / 839.68 / 139.65498057713515 / 16.63192889876324|
|all_dmc / 1|STEADY|[136,140) / 137|1024|1024|4 / 1024.0 / 0.0 / 0.0|

Candidate boundaries and confirmations are derived by exact Fraction OLS on independent new/full/owned windows, with the declared thresholds and consecutive K. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.

## Nonfatal performance settlement

BW_SUMMARY status=FAIL pass=7 fail=1 warning=0 scopes_done=16 scopes_expected=16

Expected conclusions from independent metric values and cfg: {'PASS': 7, 'FAIL': 1, 'WARNING': 0}. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.

```text
BW_CHECK scope_kind=0 scope=tb.top.master0.bw epoch=0 episode=1 result_seq=1 kind=phase phase=1 metric=ramp_time unit=ns start_ticks=31000000 end_ticks=37000000 actual=6 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=688 events=12 duration_ticks=6000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=1 basis=0 W=10 S=1 samples=6 first_sample_ticks=31000000 last_sample_ticks=36000000 sample_span_ticks=5000000 mean_gbps=72 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e5_ns/expect.cfg min_line=0 max_line=5 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=tb.top.master0.bw epoch=0 episode=1 result_seq=6 kind=phase phase=6 metric=ramp_time unit=ns start_ticks=92000000 end_ticks=100000000 actual=8 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=1024 events=16 duration_ticks=8000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=6 basis=0 W=10 S=1 samples=8 first_sample_ticks=92000000 last_sample_ticks=99000000 sample_span_ticks=7000000 mean_gbps=94.400000000000006 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e5_ns/expect.cfg min_line=0 max_line=5 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=tb.top.master0.bw epoch=0 episode=1 result_seq=10 kind=phase phase=10 metric=ramp_time unit=ns start_ticks=126000000 end_ticks=136000000 actual=10 has_min=0 min=0 has_max=1 max=30 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=30 bytes=1280 events=20 duration_ticks=10000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=1 phase_result_seq=10 basis=0 W=10 S=1 samples=10 first_sample_ticks=126000000 last_sample_ticks=135000000 sample_span_ticks=9000000 mean_gbps=104.96000000000002 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e5_ns/expect.cfg min_line=0 max_line=5 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=tb.top.master0.bw epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=20000000 end_ticks=140000000 actual=92.266666666666666 has_min=1 min=60 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=60 effective_max=0 bytes=11072 events=188 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=119 first_sample_ticks=21000000 last_sample_ticks=139000000 sample_span_ticks=118000000 mean_gbps=87.126050420168099 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e5_ns/expect.cfg min_line=4 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=tb.top.master0.bw epoch=0 episode=1 result_seq=1 kind=last_steady phase=11 metric=steady_bw unit=GB/s start_ticks=136000000 end_ticks=140000000 actual=128 has_min=1 min=80 has_max=0 max=0 abs_tol=0 rel_tol_pct=5 effective_min=76 effective_max=0 bytes=512 events=8 duration_ticks=4000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=11 basis=0 W=10 S=1 samples=4 first_sample_ticks=136000000 last_sample_ticks=139000000 sample_span_ticks=3000000 mean_gbps=128 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e5_ns/expect.cfg min_line=2 max_line=0 abs_line=0 rel_line=3 conclusion=PASS reason=NONE
BW_CHECK scope_kind=0 scope=tb.top.master0.bw epoch=0 episode=1 result_seq=1 kind=last_steady phase=11 metric=steady_cv unit=% start_ticks=136000000 end_ticks=140000000 actual=0 has_min=0 min=0 has_max=1 max=5 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=5 bytes=512 events=8 duration_ticks=4000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=11 basis=0 W=10 S=1 samples=4 first_sample_ticks=136000000 last_sample_ticks=139000000 sample_span_ticks=3000000 mean_gbps=128 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e5_ns/expect.cfg min_line=0 max_line=6 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
BW_CHECK scope_kind=1 scope=memory_all epoch=0 episode=1 result_seq=1 kind=episode phase=0 metric=episode_cv unit=% start_ticks=20000000 end_ticks=140000000 actual=38.362324335250982 has_min=0 min=0 has_max=1 max=10 abs_tol=0 rel_tol_pct=0 effective_min=0 effective_max=10 bytes=92416 events=1504 duration_ticks=120000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=0 phase_result_seq=0 basis=0 W=10 S=1 samples=119 first_sample_ticks=21000000 last_sample_ticks=139000000 sample_span_ticks=118000000 mean_gbps=729.27731092436977 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e5_ns/expect.cfg min_line=0 max_line=9 abs_line=0 rel_line=0 conclusion=FAIL reason=NONE
BW_CHECK scope_kind=1 scope=memory_all epoch=0 episode=1 result_seq=1 kind=last_steady phase=11 metric=steady_bw unit=GB/s start_ticks=136000000 end_ticks=140000000 actual=1024 has_min=1 min=160 has_max=0 max=0 abs_tol=0 rel_tol_pct=0 effective_min=160 effective_max=0 bytes=4096 events=64 duration_ticks=4000000 bytes_complete=1 events_complete=1 first_known=1 last_known=1 tail_known=1 duration_valid=1 member_reset=0 phase_kind=2 phase_result_seq=11 basis=0 W=10 S=1 samples=4 first_sample_ticks=136000000 last_sample_ticks=139000000 sample_span_ticks=3000000 mean_gbps=1024 interval_known=1 coverage_complete=1 minmax_valid=1 stddev_valid=1 cv_valid=1 minmax_reason=NONE stddev_reason=NONE cv_reason=NONE excluded_warmup=0 excluded_foreign=0 unknown_samples=0 excluded_denominator=0 cfg_file=/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/e5_ns/expect.cfg min_line=8 max_line=0 abs_line=0 rel_line=0 conclusion=PASS reason=NONE
```

[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.
