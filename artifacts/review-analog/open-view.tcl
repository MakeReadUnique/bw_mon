# The saved views contain only aliases, native analog display settings and markers.
# All values come from the unchanged acceptance FSDB referenced by each view.
cd [file dirname [file normalize [info script]]]
set view $env(BW_ANALOG_VIEW)
set fd [open "$view.sav" r]
set saved_view [read $fd]
close $fd
if {![regexp {openDirFile -d / "" "([^"]+)"} $saved_view unused fsdb]} {
    error "Missing FSDB reference in saved view"
}
set absolute_fsdb [file normalize $fsdb]
wvOpenFile $absolute_fsdb
set w [wvGetCurrentWindow]
# Native nWave path resolution retains the launch directory after Tcl cd.
# Resolve the portable FSDB reference in a temporary view, without changing it.
set resolved_view [string map [list $fsdb $absolute_fsdb] $saved_view]
set scratch "/tmp/bw-analog-view-[pid]-[clock clicks].sav"
set fd [open $scratch w]
puts $fd $resolved_view
close $fd
set restored [wvRestoreSignal -win $w -appendSignals off $scratch]
file delete $scratch
if {!$restored} {error "Cannot restore $view.sav"}
wvSetPreference -win $w -hierName off -hier_signal_name off -leftalign on -dispFileName off -dispFileNumber off
wvSetDefaultValue -win $w -analogFormat Engineer -analogPrecision 2
if {$view eq "varying_ns" || $view eq "varying_steady_ns"} {
    wvAddAliasTable -table BW_PHASE -row NONE "2'b00"
    wvAddAliasTable -table BW_PHASE -row RAMP "2'b01"
    wvAddAliasTable -table BW_PHASE -row STEADY "2'b10"
    wvAddAliasTable -table BW_PHASE -row FALL "2'b11"
    foreach name {p0_phase_candidate p0_phase_confirmed} {
        wvSelectSignal -win $w "/tb_acceptance_ns/scene/ports\[0\]/dut/mon/$name"
        wvSetAliasTable -win $w -table BW_PHASE
    }
}
wvSelectSignal -win $w {}
update
