set w [lindex [wvGetAllWindows] 0]
wvAddSignal -win $w -clear {/tb_acceptance_cycle/scene/ports[0]/dut/mon/scope_id} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_id} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_active} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_first_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_bytes} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_episode_id} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_status} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_first_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_last_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_tail_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_confirmation_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_byte_count} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_event_count} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_duration_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_tail_known} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_bytes_complete} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_e2e_valid} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_e2e_gbps} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_result_seq} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_selection_valid} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_start_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_end_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_bandwidth_valid} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_bandwidth_gbps} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_variation_mean_gbps} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_variation_stddev_gbps} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_variation_cv_valid} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_variation_cv_pct}
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_result_e2e_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_variation_mean_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_last_steady_variation_stddev_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/ports[0]/dut/mon/episode_variation_cv_pct}
wvBusWaveform -win $w -digital
wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on
wvSetRadix -win $w -Unsigned -format Dec {/tb_acceptance_cycle/scene/ports[0]/dut/accounted_bytes}
wvSetWindowTimeUnit -win $w 1 ns
wvZoom -win $w 100.0 110.000001
wvSetCursor -win $w 110.000001
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-pa98dpk9/before.sav}
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-pa98dpk9/before.sav} r]
set value [read $fd]
close $fd
regsub {viewPort[^\n]*} $value {viewPort 10 10 1500 850 760 180} value
regsub {top [0-9]+} $value {top 0} value
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-pa98dpk9/layout.sav} w]
puts $fd $value
close $fd
wvRestoreSignal -win $w -appendSignals off {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-pa98dpk9/layout.sav}
wvSetRadix -win $w -Unsigned -format Dec {(G1 2)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 3)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 4)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 5)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 6)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 8)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 9)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 10)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 11)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 12)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 13)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 14)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 15)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 16)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 17)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 19)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 20)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 21)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 22)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 23)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 27)}
set fd [open {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/truncated_cycle/episode.ready} w]
puts $fd $w
close $fd
after 3000
update
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/truncated_cycle/episode.sav}
wvCapture -win $w -file {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/truncated_cycle/episode.png}
wvExit
