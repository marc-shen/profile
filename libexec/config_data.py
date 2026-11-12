"""Allow standalone backends to read Workbench declarations."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
from workbench.data import read, specifications, install_specs, tool_specs, language_specs, plugin_sources, network_sources
