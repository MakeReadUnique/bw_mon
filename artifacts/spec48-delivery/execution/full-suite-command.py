import argparse,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--mode',required=True,choices=['cold','hot']);p.add_argument('--root',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
# Same preparation as make scale-full, inside the measured outer command.
subprocess.check_call([sys.executable,'tools/evidence.py','restore','common'],cwd=str(a.root))
raise SystemExit(subprocess.call([sys.executable,'tests/scale/revised_suite.py','full','--cache-mode',a.mode,'--output-root',str(a.output),'--lock','/tmp/bw-mon-spec48/acceptance.lock'],cwd=str(a.root)))
