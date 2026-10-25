set w [lindex [wvGetAllWindows] 0]
wvAddSignal -win $w -clear {/tb_acceptance_ns/scene/ports[0]/dut/mon/bandwidth_gbps} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_full} {/tb_acceptance_ns/scene/ports[0]/dut/mon/bytes_complete} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_current} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_candidate} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_candidate_count} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_candidate_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_start_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_confirmation_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_evidence_count} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_evidence_span} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_fit_mean} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_fit_delta} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_fit_rms} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_result_result_seq} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_result_phase_id} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_result_start_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_result_end_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_duration_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_duration_valid} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_bandwidth_gbps} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_variation_sample_count} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_variation_mean_gbps} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_variation_stddev_gbps} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_result_result_seq} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_last_steady_selection_valid} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_last_steady_start_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_last_steady_end_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_last_steady_bandwidth_gbps} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_variation_cv_valid} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_variation_cv_pct}
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_fit_mean}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_fit_delta}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_fit_rms}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_variation_mean_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_variation_stddev_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_last_steady_bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_variation_cv_pct}
wvBusWaveform -win $w -digital
wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on
wvSetRadix -win $w -Unsigned -format Dec {/tb_acceptance_ns/scene/ports[0]/dut/accounted_bytes}
wvSetWindowTimeUnit -win $w 1 ns
wvZoom -win $w 20.0 155.0
wvSetCursor -win $w 153.000001
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-z9mzmi5e/before.sav}
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-z9mzmi5e/before.sav} r]
set value [read $fd]
close $fd
regsub {viewPort[^\n]*} $value {viewPort 10 10 1500 850 760 180} value
regsub {top [0-9]+} $value {top 0} value
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-z9mzmi5e/layout.sav} w]
puts $fd $value
close $fd
wvRestoreSignal -win $w -appendSignals off {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-z9mzmi5e/layout.sav}
wvSetRadix -win $w -Unsigned -format Dec {(G1 2)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 3)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 6)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 7)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 8)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 9)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 10)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 11)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 15)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 16)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 17)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 18)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 19)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 20)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 22)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 25)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 26)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 27)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 28)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 30)}
set fd [open {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_ns/phase.ready} w]
puts $fd $w
close $fd
after 3000
update
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_ns/phase.sav}
wvCapture -win $w -file {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/varying_ns/phase.png}
wvExit
