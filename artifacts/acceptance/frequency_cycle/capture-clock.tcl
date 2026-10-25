set w [lindex [wvGetAllWindows] 0]
wvAddSignal -win $w -clear {/tb_acceptance_cycle/scene/ports[0]/dut/clk} {/tb_acceptance_cycle/scene/ports[0]/dut/valid} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/result_seq} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/accepted_record_seq} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/window_start_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/window_end_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/coverage_ticks} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/window_start_cycle} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/window_end_cycle} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/coverage_cycles} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/window_bytes} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/window_events} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/bandwidth_gbps} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/bytes_per_cycle} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/window_full} {/tb_acceptance_cycle/scene/ports[0]/dut/mon/bytes_complete} {/tb_acceptance_cycle/scene/all_dmc/result_seq} {/tb_acceptance_cycle/scene/all_dmc/window_start_ticks} {/tb_acceptance_cycle/scene/all_dmc/window_end_ticks} {/tb_acceptance_cycle/scene/all_dmc/coverage_ticks} {/tb_acceptance_cycle/scene/all_dmc/coverage_cycles} {/tb_acceptance_cycle/scene/all_dmc/window_bytes} {/tb_acceptance_cycle/scene/all_dmc/bandwidth_gbps} {/tb_acceptance_cycle/scene/all_dmc/bytes_per_cycle} {/tb_acceptance_cycle/scene/all_dmc/window_full} {/tb_acceptance_cycle/scene/all_dmc/bytes_complete}
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/ports[0]/dut/mon/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/ports[0]/dut/mon/bytes_per_cycle}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/all_dmc/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_cycle/scene/all_dmc/bytes_per_cycle}
wvBusWaveform -win $w -digital
wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on
wvSetRadix -win $w -Unsigned -format Dec {/tb_acceptance_cycle/scene/ports[0]/dut/accounted_bytes}
wvSetWindowTimeUnit -win $w 1 ns
wvZoom -win $w 72.0 116.0
wvSetCursor -win $w 103.500001
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-iehc0ye1/before.sav}
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-iehc0ye1/before.sav} r]
set value [read $fd]
close $fd
regsub {viewPort[^\n]*} $value {viewPort 10 10 1500 850 760 180} value
regsub {top [0-9]+} $value {top 0} value
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-iehc0ye1/layout.sav} w]
puts $fd $value
close $fd
wvRestoreSignal -win $w -appendSignals off {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-iehc0ye1/layout.sav}
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
wvSetRadix -win $w -Unsigned -format Dec {(G1 15)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 16)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 17)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 18)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 19)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 20)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 21)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 22)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 25)}
wvSetRadix -win $w -Unsigned -format Dec {(G1 26)}
set fd [open {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_cycle/clock.ready} w]
puts $fd $w
close $fd
after 3000
update
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_cycle/clock.sav}
wvCapture -win $w -file {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/frequency_cycle/clock.png}
wvExit
