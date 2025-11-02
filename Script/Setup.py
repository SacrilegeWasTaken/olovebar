#!/usr/bin/env python3
import subprocess
import sys
import shutil
import platform

def check_command(cmd):
    return shutil.which(cmd) is not None

def check_macos_version():
    version = platform.mac_ver()[0]
    major = int(version.split('.')[0])
    if major < 26:
        print(f"✗ macOS {version} detected. macOS 26+ required.")
        sys.exit(1)
    print(f"✓ macOS {version}")
    return version

def install_brew():
    print("Installing Homebrew...")
    subprocess.run([
        '/bin/bash', '-c',
        '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'
    ], check=True)

def install_uv():
    print("Installing uv...")
    subprocess.run(['brew', 'install', 'uv'], check=True)

def install_swift():
    print("Installing Xcode Command Line Tools (includes Swift)...")
    subprocess.run(['xcode-select', '--install'], check=False)
    print("Please complete the installation dialog and run this script again.")
    sys.exit(0)

def main():
    check_macos_version()
    
    if not check_command('aerospace'):
        print("⚠️  Aerospace not found")
        print("   Install from: https://github.com/nikitabobko/AeroSpace")
        print("   Don't forget to configure and run it on startup!")
        print("   Aerospace must be running before olovebar!")
    else:
        print("✓ Aerospace found")
    
    if not check_command('brew'):
        print("✗ Homebrew not found")
        install_brew()
        print("✓ Homebrew installed")
    else:
        print("✓ Homebrew found")
    
    if not check_command('swift'):
        print("✗ Swift not found")
        install_swift()
    else:
        print("✓ Swift found")
    
    if not check_command('uv'):
        print("✗ uv not found")
        install_uv()
        print("✓ uv installed")
    else:
        print("✓ uv found")
    
    print("\n✓ All dependencies installed")

if __name__ == "__main__":
    main()
