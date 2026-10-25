set w [lindex [wvGetAllWindows] 0]
wvAddSignal -win $w -clear {/tb_acceptance_ns/scene/ports[0]/dut/reset_n} {/tb_acceptance_ns/scene/ports[0]/dut/valid} {/tb_acceptance_ns/scene/ports[0]/dut/accounted_bytes} {/tb_acceptance_ns/scene/ports[0]/dut/accounted_known} {/tb_acceptance_ns/scene/ports[0]/dut/mon/sampled_reset_n} {/tb_acceptance_ns/scene/ports[0]/dut/mon/sampled_valid} {/tb_acceptance_ns/scene/ports[0]/dut/mon/sampled_size_known} {/tb_acceptance_ns/scene/ports[0]/dut/mon/sampled_size_bytes} {/tb_acceptance_ns/scene/ports[0]/dut/mon/stats_epoch} {/tb_acceptance_ns/scene/ports[0]/dut/mon/total_bytes} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_start_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_end_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_bytes} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_full} {/tb_acceptance_ns/scene/ports[0]/dut/mon/bytes_complete} {/tb_acceptance_ns/scene/ports[0]/dut/mon/events_complete} {/tb_acceptance_ns/scene/ports[0]/dut/mon/member_reset_coverage} {/tb_acceptance_ns/scene/die0/stats_epoch} {/tb_acceptance_ns/scene/die0/window_warmup} {/tb_acceptance_ns/scene/all_dmc/stats_epoch} {/tb_acceptance_ns/scene/all_dmc/window_bytes} {/tb_acceptance_ns/scene/all_dmc/bytes_complete} {/tb_acceptance_ns/scene/all_dmc/events_complete} {/tb_acceptance_ns/scene/all_dmc/member_reset_coverage} {/tb_acceptance_ns/scene/all_dmc/bandwidth_gbps} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_id} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_active} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_bytes_complete} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_events_complete} {/tb_acceptance_ns/scene/ports[0]/dut/mon/episode_e2e_valid}
wvSelectSignal -win $w {/tb_acceptance_ns/scene/all_dmc/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on
wvSetRadix -win $w -Unsigned -format Dec {/tb_acceptance_ns/scene/ports[0]/dut/accounted_bytes}
wvSetWindowTimeUnit -win $w 1 ns
wvZoom -win $w 100.0 118.0
wvSetCursor -win $w 105.000001
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-neknlmaz/before.sav}
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-neknlmaz/before.sav} r]
set value [read $fd]
close $fd
regsub {viewPort[^\n]*} $value {viewPort 10 10 1500 850 760 180} value
regsub {top [0-9]+} $value {top 0} value
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-neknlmaz/layout.sav} w]
puts $fd $value
close $fd
wvRestoreSignal -win $w -appendSignals off {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-neknlmaz/layout.sav}
wvSetRadix -win $w -Unsigned -format Dec {(G1 1)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 2)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 3)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 4)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 5)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 6)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 7)}
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
wvSetRadix -win $w -Unsigned -format Dec {(G1 18)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 19)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 20)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 21)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 22)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 23)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 24)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 26)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 27)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 28)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 29)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 30)}
set fd [open {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/quality.ready} w]
puts $fd $w
close $fd
after 3000
update
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/quality.sav}
wvCapture -win $w -file {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/upper_reset_ns/quality.png}
wvExit
