#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

def main():
    binary_path = Path("/usr/local/bin/olovebar")
    
    if not binary_path.exists():
        print("✓ olovebar not installed")
        sys.exit(0)
    
    print(f"Removing {binary_path}...")
    result = subprocess.run(["sudo", "rm", str(binary_path)])
    
    if result.returncode != 0:
        print("✗ Failed to remove olovebar", file=sys.stderr)
        sys.exit(1)
    
    print("✓ olovebar uninstalled successfully")

if __name__ == "__main__":
    main()
