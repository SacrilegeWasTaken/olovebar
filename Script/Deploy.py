#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

def main():
    project_root = Path(__file__).parent.parent
    binary_name = "olovebar"
    install_path = Path("/usr/local/bin") / binary_name
    
    print("Building release binary...")
    result = subprocess.run(
        ["swift", "build", "-c", "release"],
        cwd=project_root,
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"Build failed:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    
    binary_path = project_root / ".build" / "release" / binary_name
    
    if not binary_path.exists():
        print(f"Binary not found at {binary_path}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Installing to {install_path}...")
    subprocess.run(["sudo", "cp", str(binary_path), str(install_path)], check=True)
    subprocess.run(["sudo", "chmod", "+x", str(install_path)], check=True)
    
    print(f"✓ {binary_name} installed successfully")
    print(f"Run with: {binary_name}")

if __name__ == "__main__":
    main()
