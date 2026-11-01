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
