if {[catch {
set w [lindex [wvGetAllWindows] 0]
wvRestoreSignal -win $w -appendSignals off {/home/eda/bw_cal/.build/verdi61/alternating/sustained_boundary.sav}
wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on
wvSetDefaultValue -win $w -analogFormat Engineer -analogPrecision 6
wvResizeWindow -win $w 10 10 1860 1000
after 800
update
set fd [open {/home/eda/bw_cal/.build/verdi61/alternating/sustained_boundary-values.tsv} w]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/scope_id} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/scope_id}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/bandwidth_gbps} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/bandwidth_gbps}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/result_seq} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/result_seq}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/window_start_ticks} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/window_start_ticks}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/window_end_ticks} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/window_end_ticks}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/window_bytes} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/window_bytes}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/window_full} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/window_full}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/bytes_complete} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/bytes_complete}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/phase_current} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/phase_current}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/phase_reason} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/phase_reason}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/phase_evidence_count} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/phase_evidence_count}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/phase_evidence_required} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/phase_evidence_required}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/phase_candidate_count} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/phase_candidate_count}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/phase_candidate_required} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/phase_candidate_required}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/phase_start_ticks} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/phase_start_ticks}]]
puts $fd [format "%s\t%s" {/tb_checker_default/group_mon/phase_confirmation_ticks} [wvGetCurValueString -win $w {/tb_checker_default/group_mon/phase_confirmation_ticks}]]
puts $fd [format "%s\t%s" {/tb_checker_default/members[0]/point/bandwidth_gbps} [wvGetCurValueString -win $w {/tb_checker_default/members[0]/point/bandwidth_gbps}]]
puts $fd [format "%s\t%s" {/tb_checker_default/members[0]/point/phase_current} [wvGetCurValueString -win $w {/tb_checker_default/members[0]/point/phase_current}]]
close $fd
wvSaveSignal -win $w {/home/eda/bw_cal/.build/verdi61/alternating/sustained_boundary.reopened.sav}
wvCapture -win $w -file {/home/eda/bw_cal/.build/verdi61/alternating/sustained_boundary.png}
wvExit

} err]} {
puts stderr $errorInfo
wvExit
}
