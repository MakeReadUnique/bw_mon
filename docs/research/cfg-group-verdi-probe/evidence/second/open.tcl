set w [lindex [wvGetAllWindows] 0]
wvRestoreSignal -win $w -appendSignals off view.sav
