import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent

def get_version_swift(path=ROOT / "Sources/OLoveBar/Version.swift"):
    with open(path) as f:
        content = f.read()
    match = re.search(r'static let current:\s*String\s*=\s*"([^"]+)"', content)
    if not match:
        print("version not found", file=sys.stderr)
        sys.exit(1)
    print(match.group(1))

get_version_swift()
