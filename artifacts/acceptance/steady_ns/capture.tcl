set w [lindex [wvGetAllWindows] 0]
wvSetDefaultValue -win $w -analogFormat Auto -analogPrecision 12
wvAddSignal -win $w -clear {/tb_acceptance_ns/scene/ports[0]/dut/clk} {/tb_acceptance_ns/scene/ports[0]/dut/reset_n} {/tb_acceptance_ns/scene/ports[0]/dut/valid} {/tb_acceptance_ns/scene/ports[0]/dut/accounted_bytes} {/tb_acceptance_ns/scene/ports[0]/dut/mon/scope_id} {/tb_acceptance_ns/scene/ports[0]/dut/mon/stats_epoch} {/tb_acceptance_ns/scene/ports[0]/dut/mon/result_seq} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_start_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_end_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_bytes} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_events} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_full} {/tb_acceptance_ns/scene/ports[0]/dut/mon/window_warmup} {/tb_acceptance_ns/scene/ports[0]/dut/mon/bytes_complete} {/tb_acceptance_ns/scene/ports[0]/dut/mon/member_reset_coverage} {/tb_acceptance_ns/scene/ports[0]/dut/mon/bandwidth_gbps} {/tb_acceptance_ns/scene/die0/bandwidth_gbps} {/tb_acceptance_ns/scene/die1/bandwidth_gbps} {/tb_acceptance_ns/scene/all_dmc/bandwidth_gbps} {/tb_acceptance_ns/scene/mixed/bandwidth_gbps} {/tb_acceptance_ns/scene/ports[10]/dut/mon/bandwidth_gbps} {/tb_acceptance_ns/scene/ports[11]/dut/mon/bandwidth_gbps} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_current} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_start_ticks} {/tb_acceptance_ns/scene/ports[0]/dut/mon/phase_confirmation_ticks}
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[0]/dut/mon/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/die0/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/die1/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/all_dmc/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/mixed/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[10]/dut/mon/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSelectSignal -win $w {/tb_acceptance_ns/scene/ports[11]/dut/mon/bandwidth_gbps}
wvBusWaveform -win $w -digital
wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on
wvSetRadix -win $w -Unsigned -format Dec {/tb_acceptance_ns/scene/ports[0]/dut/accounted_bytes}
wvSetWindowTimeUnit -win $w 1 ns
wvZoom -win $w 88 112
wvSetCursor -win $w 102.000001
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-1fbxvmi1/before.sav}
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-1fbxvmi1/before.sav} r]
set value [read $fd]
close $fd
regsub {viewPort[^\n]*} $value {viewPort 10 10 1500 850 660 180} value
regsub {top [0-9]+} $value {top 0} value
set fd [open {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-1fbxvmi1/layout.sav} w]
puts $fd $value
close $fd
wvRestoreSignal -win $w -appendSignals off {/tmp/bw-mon-spec13/wt-28/.build/acceptance/verdi-1fbxvmi1/layout.sav}
wvSetRadix -win $w -Unsigned -format Dec {(G1 4)}
set fd [open {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/steady_ns/capture.ready} w]
puts $fd $w
close $fd
after 3000
update
wvSaveSignal -win $w {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/steady_ns/overview.sav}
wvCapture -win $w -file {/tmp/bw-mon-spec13/wt-28/artifacts/acceptance/steady_ns/overview.png}
wvExit
