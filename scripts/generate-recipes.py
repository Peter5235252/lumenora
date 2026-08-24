#!/usr/bin/env python3
"""Generate the three BlueBuild recipes from one canonical template."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "recipes" / "recipe-template.yml"
VARIANTS = {
    "recipe.yml": {
        "name": "lumenora",
        "description": "A KDE Plasma gaming distro built on Fedora Atomic with automatic GPU driver handling",
        "akmods": "",
    },
    "recipe-nvidia.yml": {
        "name": "lumenora-nvidia",
        "description": "Lumenora KDE Plasma gaming distro with the NVIDIA driver (akmods, proprietary flavor)",
        "akmods": "  - type: akmods\n    base: ogc\n    nvidia-driver: nvidia-open\n    install: []\n\n",
    },
    "recipe-nvidia-open.yml": {
        "name": "lumenora-nvidia-open",
        "description": "Lumenora KDE Plasma gaming distro with the NVIDIA driver (akmods, open kernel flavor, Turing and newer)",
        "akmods": "  - type: akmods\n    base: ogc\n    nvidia-driver: nvidia-open\n    install: []\n\n",
    },
}

def render(spec):
    text = TEMPLATE.read_text(encoding="utf-8")
    for key, value in spec.items():
        text = text.replace("{{" + key.upper() + "}}", value)
    if "{{" in text:
        raise SystemExit("unresolved template placeholder")
    return text

check = "--check" in sys.argv
for filename, spec in VARIANTS.items():
    path = ROOT / "recipes" / filename
    rendered = render(spec)
    if check:
        if not path.exists() or path.read_text(encoding="utf-8") != rendered:
            print(f"{path.relative_to(ROOT)} is out of date", file=sys.stderr)
            raise SystemExit(1)
    else:
        path.write_text(rendered, encoding="utf-8")
