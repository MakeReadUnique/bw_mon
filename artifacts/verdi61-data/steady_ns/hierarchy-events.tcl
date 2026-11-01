srcResizeWindow 0 0 1920 1080
srcSelect -inst {tb_acceptance_ns.scene.all_dmc}
srcShowCalling {tb_acceptance_ns.scene.all_dmc}
srcSignalView -on
srcSignalViewSetFilter {*bandwidth*}
if {[llength [wvGetAllWindows]] == 0} {wvCreateWindow}
set w [lindex [wvGetAllWindows] 0]
wvResizeWindow -win $w 900 450 1010 580
wvSetWindowTimeUnit -win $w 1 ns
wvZoom -win $w 88 112
wvSetCursor -win $w 102.000002
puts "HIERARCHY_READY"

proc review_poll {} {
  global w errorInfo
  set command {/home/eda/bw_cal/.build/verdi61/control.tcl}
  if {[file exists $command]} {
    if {[catch {source $command} err]} {puts stderr $errorInfo}
    file delete $command
  }
  after 300 review_poll
}
review_poll
srcHBSelect "tb_acceptance_ns.scene.all_dmc" -win $_nTrace1
srcSetScope "tb_acceptance_ns.scene.all_dmc" -delim "." -win $_nTrace1
srcHBSelect "tb_acceptance_ns.scene.all_dmc" -win $_nTrace1
verdiSetActWin -dock widgetDock_<Inst._Tree>
srcSignalViewSelect "tb_acceptance_ns.scene.all_dmc.bandwidth_gbps"
verdiSetActWin -dock widgetDock_<Signal_List>
wvAddSignal -win $_nWave2 "/tb_acceptance_ns/scene/all_dmc/bandwidth_gbps"
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSaveSignal -win $_nWave2 \
           "/home/eda/bw_cal/.build/verdi61/hierarchy-dragged.sav"
wvRestoreSignal -win $_nWave2 "/home/eda/bw_cal/.build/verdi61/named_group.sav" \
           -overWriteAutoAlias on -appendSignals off
wvSetPreference -hier_signal_name on
wvSetPreference -partial_hier off
wvSetPreference -leftalign on
wvSetPreference -hierName on
wvSetPreference -analogPrecision 6
wvSetPreference -analogFormat Engineer -analogPrecision 6
srcShowCalling "tb_acceptance_ns.scene.all_dmc" -win $_nTrace1
srcSelect -win $_nTrace1 -range {79 79 24 25 1 1}
srcHBSelect "tb_acceptance_ns.scene" -win $_nTrace1
wvSaveSignal -win $_nWave2 \
           "/home/eda/bw_cal/.build/verdi61/named_group.reopened.sav"
srcSignalView -off
srcHBSelect "tb_acceptance_ns.scene.all_dmc" -win $_nTrace1
verdiSetActWin -dock widgetDock_<Inst._Tree>
