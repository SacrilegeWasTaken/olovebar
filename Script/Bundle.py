#!/usr/bin/env python3
"""
Bundle script for OLoveBar macOS application.
Creates .app bundle with proper structure and Info.plist.
"""

import sys
import shutil
import subprocess
from pathlib import Path


def create_icon(icon_source: Path, resources_dir: Path) -> None:
    """Generate .icns icon from source PNG."""
    if not icon_source.exists():
        print(f"Icon source not found: {icon_source}")
        return
    
    print(f"Generating AppIcon.icns from {icon_source}")
    iconset_dir = resources_dir / "AppIcon.iconset"
    iconset_dir.mkdir(exist_ok=True)
    
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    
    for size, name in sizes:
        subprocess.run(
            ["sips", "-z", str(size), str(size), str(icon_source), 
             "--out", str(iconset_dir / name)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    
    # Create .icns
    icns_path = resources_dir / "AppIcon.icns"
    subprocess.run(
        ["iconutil", "-c", "icns", str(iconset_dir), "-o", str(icns_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    
    # Copy PNG for status bar
    shutil.copy(icon_source, resources_dir / "logo.png")
    
    # Cleanup
    shutil.rmtree(iconset_dir)


def create_bundle(executable_path: Path, output_path: Path, bundle_id: str = "com.sacrilege.olovebar") -> None:
    """Create macOS .app bundle."""
    if not executable_path.exists():
        print(f"Error: Executable not found: {executable_path}")
        sys.exit(2)
    
    # Remove existing bundle
    if output_path.exists():
        shutil.rmtree(output_path)
    
    # Create bundle structure
    macos_dir = output_path / "Contents" / "MacOS"
    resources_dir = output_path / "Contents" / "Resources"
    macos_dir.mkdir(parents=True)
    resources_dir.mkdir(parents=True)
    
    # Copy executable
    app_name = "OLoveBar"
    dest_exec = macos_dir / app_name
    shutil.copy(executable_path, dest_exec)
    dest_exec.chmod(0o755)
    
    # Copy Info.plist
    info_plist = Path("Info.plist")
    if info_plist.exists():
        shutil.copy(info_plist, output_path / "Contents" / "Info.plist")
    else:
        print(f"Warning: Info.plist not found at {info_plist}")
    
    # Generate icon
    icon_source = Path("Resources/logo.png")
    if icon_source.exists():
        create_icon(icon_source, resources_dir)
    
    # Create PkgInfo
    (output_path / "Contents" / "PkgInfo").write_text("APPL????")
    
    print(f"✅ Created app bundle at {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <executable-path> <output-app-path> [bundle-id]")
        sys.exit(2)
    
    executable = Path(sys.argv[1])
    output = Path(sys.argv[2])
    bundle_id = sys.argv[3] if len(sys.argv) > 3 else "com.sacrilege.olovebar"
    
    create_bundle(executable, output, bundle_id)
