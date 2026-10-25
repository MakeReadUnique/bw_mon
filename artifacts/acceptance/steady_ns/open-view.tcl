set w [lindex [wvGetAllWindows] 0]
set view overview
if {[info exists env(BW_VIEW)]} {set view $env(BW_VIEW)}
wvRestoreSignal -win $w -appendSignals off "$view.sav"
wvSetPreference -win $w -hierName on -partial_hier off -hier_signal_name on
update
