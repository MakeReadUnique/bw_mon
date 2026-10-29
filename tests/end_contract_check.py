#!/usr/bin/env python3
"""Ticket 56 final-contract checker: separate externally observable states.

Reads one simulation log and classifies the four ending dimensions that the
spec requires to be independently judgeable:

  process state      TB_PASS / Fatal exit evidence in the log
  report completion  count of BW_REPORT_COMPLETE / BW_REPORT_INCOMPLETE
  monitoring integrity  integrity=COMPLETE|INCOMPLETE plus real terminal
                      states it must agree with
  performance        presence and status of BW_SUMMARY

A killed or stalled process never reaches these lines; its absence is the
external evidence of an unclean ending and must not be replaced by invented
in-library missing-frame diagnostics.

Usage: end_contract_check.py <log> <complete|incomplete|aborted|killed>
"""
import re
import sys

COMPLETE, INCOMPLETE, ABORTED, KILLED = ("complete", "incomplete", "aborted",
                                         "killed")


def fail(reason):
    print("END_CONTRACT_FAIL: " + reason)
    sys.exit(1)


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in (COMPLETE, INCOMPLETE,
                                                 ABORTED, KILLED):
        print(__doc__)
        sys.exit(2)
    log = open(sys.argv[1]).read()
    mode = sys.argv[2]
    markers = re.findall(r"BW_REPORT_COMPLETE", log)
    incompletes = re.findall(r"BW_REPORT_INCOMPLETE reason=([A-Z_]+)", log)
    summaries = re.findall(r"BW_SUMMARY status=(\w+)", log)
    terminals = re.findall(
        r"BW_(?:POINT|GROUP)_TERMINAL scope=\S+ state=(\w+)", log)

    # Process state.
    if mode == ABORTED:
        if "Fatal:" not in log:
            fail("aborted ending must carry the simulator's fatal evidence")
        if "TB_PASS" in log:
            fail("an aborted run must not claim TB_PASS")
    elif mode == KILLED:
        # Only external evidence expresses an unclean kill: no TB_PASS, no
        # fatal diagnostic, and no invented in-library missing-frame output.
        if "TB_PASS" in log:
            fail("a killed run must not claim TB_PASS")
        if "Fatal:" in log:
            fail("a killed run has no simulator fatal evidence to rely on")
    else:
        if "TB_PASS" not in log:
            fail("clean ending must carry TB_PASS")
        if "Fatal:" in log:
            fail("a clean ending must not contain Fatal:")

    # Report completion marker.
    if mode in (ABORTED, KILLED):
        if markers:
            fail("an unclean ending must not emit the completion marker")
        if summaries:
            fail("an unclean ending must not emit a normal summary")
    else:
        if len(markers) != 1:
            fail("exactly one completion marker required, found %d"
                 % len(markers))
        if incompletes:
            fail("a completed report must not also carry %r" % incompletes)

    # Monitoring integrity is judged independently of the marker's presence:
    # the integrity named on the marker must agree with the real terminal
    # states, whichever way it goes.
    if mode not in (ABORTED, KILLED):
        bad = [t for t in terminals if t in ("DISABLED", "INTERRUPTED")]
        named_incomplete = "integrity=INCOMPLETE" in log
        if bad and not named_incomplete:
            fail("disabled/interrupted terminals require integrity=INCOMPLETE")
        if not bad and named_incomplete:
            fail("integrity=INCOMPLETE needs a real disabled/interrupted "
                 "terminal as evidence")
    if mode == INCOMPLETE and "integrity=INCOMPLETE" not in log:
        fail("incomplete monitoring must be named on the marker")

    # Performance is independently judgeable and never implied by the marker.
    if mode == COMPLETE and not summaries:
        fail("a completed normal report must carry one BW_SUMMARY")

    print("END_CONTRACT_PASS mode=%s markers=%d summaries=%d terminals=%s"
          % (mode, len(markers), len(summaries),
             ",".join(sorted(set(terminals))) or "-"))
    sys.exit(0)


if __name__ == "__main__":
    main()
