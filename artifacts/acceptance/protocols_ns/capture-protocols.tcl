set w [lindex [wvGetAllWindows] 0]
wvAddSignal -win $w -clear {/tb_acceptance_ns/scene/ports[1]/dut/valid} {/tb_acceptance_ns/scene/ports[1]/dut/ready} {/tb_acceptance_ns/scene/ports[1]/dut/mon/sampled_valid} {/tb_acceptance_ns/scene/ports[1]/dut/mon/sampled_ready} {/tb_acceptance_ns/scene/ports[1]/dut/mon/total_events} {/tb_acceptance_ns/scene/ports[1]/dut/mon/window_events} {/tb_acceptance_ns/scene/ports[1]/dut/mon/bytes_complete} {/tb_acceptance_ns/scene/ports[1]/dut/mon/events_complete} {/tb_acceptance_ns/scene/ports[1]/dut/mon/backpressure_hit_count} {/tb_acceptance_ns/scene/ports[1]/dut/mon/backpressure_duration_ticks} {/tb_acceptance_ns/scene/ports[2]/dut/valid} {/tb_acceptance_ns/scene/ports[2]/dut/flitv} {/tb_acceptance_ns/scene/ports[2]/dut/lcrdv} {/tb_acceptance_ns/scene/ports[2]/dut/mon/credit_balance} {/tb_acceptance_ns/scene/ports[2]/dut/mon/credit_trusted} {/tb_acceptance_ns/scene/ports[2]/dut/mon/credit_anomaly} {/tb_acceptance_ns/scene/ports[2]/dut/mon/total_events} {/tb_acceptance_ns/scene/ports[2]/dut/mon/window_events} {/tb_acceptance_ns/scene/ports[2]/dut/mon/bandwidth_gbps} {/tb_acceptance_ns/scene/all_dmc/window_bytes} {/tb_acceptance_ns/scene/all_dmc/bytes_complete} {/tb_acceptance_ns/scene/all_dmc/events_complete}
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[2]/dut/mon/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on
wvSetRadix -win $w -Unsigned -format Dec {/tb_acceptance_ns/scene/ports[0]/dut/accounted_bytes}
wvSetWindowTimeUnit -win $w 1 ns
wvZoom -win $w 59.0 66.0
wvSetCursor -win $w 61.000001
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-fl2uzui2/before.sav}
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-fl2uzui2/before.sav} r]
set value [read $fd]
close $fd
regsub {viewPort[^\n]*} $value {viewPort 10 10 1500 850 760 180} value
regsub {top [0-9]+} $value {top 0} value
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-fl2uzui2/layout.sav} w]
puts $fd $value
close $fd
wvRestoreSignal -win $w -appendSignals off {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-fl2uzui2/layout.sav}
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
wvSetRadix -win $w -Unsigned -format Dec {(G1 20)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 21)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 22)}
set fd [open {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_ns/protocols.ready} w]
puts $fd $w
close $fd
after 3000
update
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_ns/protocols.sav}
wvCapture -win $w -file {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/protocols_ns/protocols.png}
wvExit
