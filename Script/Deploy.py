#!/usr/bin/env python3

import os
import subprocess
import shutil
import argparse
from pathlib import Path

def create_dmg(app_path, dmg_path):
    # Convert to Path objects
    app_path = Path(app_path)
    dmg_path = Path(dmg_path)
    
    # Check if app exists
    if not app_path.exists():
        print(f"Error: {app_path} not found.")
        return False
    
    # Ensure output directory exists
    dmg_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Ensure .dmg extension
    if not dmg_path.suffix == '.dmg':
        dmg_path = dmg_path.with_suffix('.dmg')
    
    # Clean up old DMG
    if dmg_path.exists():
        os.remove(dmg_path)
        print(f"Removed old {dmg_path.name}")
    
    # Create temporary directory
    temp_dir = dmg_path.parent / "temp_dmg"
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    temp_dir.mkdir()
    
    # Copy app to temp directory
    shutil.copytree(app_path, temp_dir / app_path.name)
    print(f"Copied {app_path.name} to temp directory")
    
    # Create symlink to Applications
    applications_link = temp_dir / "Applications"
    os.symlink("/Applications", applications_link)
    print("Created Applications symlink")
    
    # Create DMG
    try:
        subprocess.run([
            "hdiutil", "create",
            "-volname", dmg_path.stem,
            "-srcfolder", str(temp_dir),
            "-ov",
            "-format", "UDZO",
            str(dmg_path)
        ], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error creating DMG: {e}")
        return False
    finally:
        # Clean up temp directory
        shutil.rmtree(temp_dir)
    
    print(f"Successfully created {dmg_path}")
    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Create DMG from .app bundle')
    parser.add_argument('--app', required=True, help='Path to .app bundle')
    parser.add_argument('--output', required=True, help='Output path for DMG file')
    
    args = parser.parse_args()
    
    create_dmg(args.app, args.output)