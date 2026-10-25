set w [lindex [wvGetAllWindows] 0]
wvRestoreSignal -win $w -appendSignals off overview.sav
wvSetPreference -win $w -hierName on -partial_hier off -hier_signal_name on
update
