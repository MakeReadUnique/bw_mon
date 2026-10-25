#!/usr/bin/env python3
"""Inspect this versioned COMMON campaign using the shared portable verifier."""
import subprocess,sys
from pathlib import Path
base=Path(__file__).resolve().parent
subprocess.run([sys.executable,str(base.parent/'verify_campaign.py'),str(base)]+sys.argv[1:],check=True)
