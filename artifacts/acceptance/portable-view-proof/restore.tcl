set w [lindex [wvGetAllWindows] 0]
wvRestoreSignal -win $w -appendSignals off {overview.sav}
update
wvSaveSignal -win $w {restored.sav}
wvExit
