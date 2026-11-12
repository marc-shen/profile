#!/usr/bin/env python3
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
from workbench.builtin import entry
name = sys.argv.pop(1)
raise SystemExit(entry(name))
