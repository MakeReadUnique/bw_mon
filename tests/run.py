#!/usr/bin/env python3
"""Compile and run real SystemVerilog contract tests with VCS."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cases", nargs="*", help="case names (default: all)")
    parser.add_argument("--no-cache", action="store_true")
    args = parser.parse_args()
    cases = json.loads((ROOT / "tests/cases.json").read_text())
    known = {case["name"] for case in cases}
    unknown = set(args.cases) - known
    if unknown:
        parser.error("unknown cases: " + ", ".join(sorted(unknown)))
    selected = [case for case in cases if not args.cases or case["name"] in args.cases]
    sources = sorted((ROOT / "rtl").glob("*.sv"), key=lambda p: (p.name != "bw_mon_pkg.sv", p.name))
    compiled = {}
    failures = []
    for case in selected:
        top = case["top"]
        build = ROOT / ".build" / "tests" / top
        build.mkdir(parents=True, exist_ok=True)
        files = sources + [ROOT / "tests" / name for name in case.get("sources", [])] + [ROOT / "tests" / (top + ".sv")]
        digest = hashlib.sha256(b"".join(path.read_bytes() for path in files)).hexdigest()
        stamp = build / "source.sha256"
        if top not in compiled:
            if args.no_cache or not (build / "simv").exists() or not stamp.exists() or stamp.read_text() != digest:
                cmd = ["vcs", "-full64", "-sverilog", "-timescale=1ns/1fs", "-debug_access+all",
                       "-top", top, "-o", str(build / "simv")] + [str(path) for path in files]
                with (build / "compile.log").open("w") as log:
                    result = subprocess.run(cmd, cwd=build, stdout=log, stderr=subprocess.STDOUT)
                compiled[top] = result.returncode == 0
                if compiled[top]:
                    stamp.write_text(digest)
            else:
                compiled[top] = True
        if not compiled[top]:
            print(f"FAIL {case['name']}: compilation; {build / 'compile.log'}")
            failures.append(case["name"])
            continue
        result = subprocess.run([str(build / "simv"), "-no_save"] + case.get("plusargs", []), cwd=build,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True, timeout=120)
        log_path = build / (case["name"] + ".log")
        log_path.write_text(result.stdout)
        if case.get("expect_error"):
            # This VCS version returns zero even for $fatal. Require its terminal
            # Fatal diagnostic and the exact core error, and reject continuation.
            passed = ("Fatal:" in result.stdout and
                      re.search(case["expect_error"], result.stdout) is not None and
                      "TB_PASS" not in result.stdout and
                      "expected core error did not occur" not in result.stdout)
        else:
            passed = (result.returncode == 0 and "TB_PASS" in result.stdout and
                      "Fatal:" not in result.stdout)
        passed = passed and all(re.search(pattern, result.stdout) is not None
                                for pattern in case.get("expect_log", []))
        passed = passed and all(len(re.findall(pattern, result.stdout)) == count
                                for pattern, count in case.get("expect_counts", {}).items())
        print(f"{'PASS' if passed else 'FAIL'} {case['name']}: {log_path}", flush=True)
        if not passed:
            failures.append(case["name"])
            print(result.stdout[-4000:])
    print(f"{len(selected)-len(failures)}/{len(selected)} contract cases passed")
    return bool(failures)

if __name__ == "__main__":
    sys.exit(main())
