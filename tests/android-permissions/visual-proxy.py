import importlib.machinery
import importlib.util
import json
import os
import sys
from pathlib import Path

source = Path(sys.argv[1])
loader = importlib.machinery.SourceFileLoader("display", str(source))
display = importlib.util.module_from_spec(
    importlib.util.spec_from_loader("display", loader)
)
loader.exec_module(display)
display.listed = lambda app: True
with open(source.with_name("wayland-protocols.json"), encoding="utf-8") as handle:
    table = json.load(handle)
runtime = os.environ["XDG_RUNTIME_DIR"]
display.serve(table, runtime, os.path.join(runtime, os.environ.get("WAYLAND_DISPLAY", "wayland-0")))
