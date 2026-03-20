#!/usr/bin/env python3
"""
Release helper for OLoveBar (minimal, env‑driven).

Responsibilities:
- Read version from VERSION
- Ensure .build/OLoveBar.dmg exists
- Compute sha256 for the DMG
- Generate / update Homebrew casks in $TAP_DIR/Casks:
  - olovebar@<version>.rb
  - olovebar.rb (latest alias)
- Commit and push changes in the tap repository.

Usage:

  TAP_DIR=/path/to/homebrew-tap uv run Script/Release.py

Environment:
- TAP_DIR          (required) — путь до корня tap‑репозитория (где лежит Casks/).
- CODEBERG_OWNER   (optional) — владелец на Codeberg для URL (default: sacrilegewastaken).
- CODEBERG_REPO    (optional) — repo name на Codeberg для URL (default: olovebar).
"""

from __future__ import annotations
import hashlib
import os
import subprocess
import sys
from pathlib import Path


def read_version() -> str:
    version = os.getenv("VERSION")
    if not version:
        print("ERROR: VERSION environment variable is not set.", file=sys.stderr)
        sys.exit(1)
    return version.strip()


def sha256_hex(path: Path) -> str:
    if not path.exists():
        print(f"ERROR: DMG not found at {path}", file=sys.stderr)
        sys.exit(1)

    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_casks(
    tap_dir: Path,
    version: str,
    sha256: str,
    owner: str = "sacrilegewastaken",
    repo: str = "olovebar",
) -> None:
    casks_dir = tap_dir / "Casks"
    casks_dir.mkdir(parents=True, exist_ok=True)

    versioned_path = casks_dir / f"olovebar@{version}.rb"
    latest_path = casks_dir / "olovebar.rb"

    # Versioned cask
    versioned_template = """cask "olovebar@{version}" do
  version "{version}"
  sha256 "{sha256}"

  url "https://codeberg.org/{owner}/{repo}/releases/download/{version}/OLoveBar.dmg"
  name "OLoveBar"
  desc "Menu bar utility"
  homepage "https://codeberg.org/{owner}/{repo}"

  postflight do
    if File.exist?("#{{staged_path}}/OLoveBar.app")
      system "xattr", "-r", "-d", "com.apple.quarantine", "#{{staged_path}}/OLoveBar.app"
    end

    if File.exist?("#{{appdir}}/OLoveBar.app")
      system "xattr", "-r", "-d", "com.apple.quarantine", "#{{appdir}}/OLoveBar.app"
    end
  end

  app "OLoveBar.app", target: "#{{appdir}}/OLoveBar.app"

  uninstall quit: "com.sacrilege.olovebar"

  zap trash: [
    "~/Library/Preferences/com.sacrilege.olovebar.plist",
    "~/Library/Application Support/OLoveBar",
  ]
end
""".format(version=version, sha256=sha256, owner=owner, repo=repo)

    # "Latest" alias cask
    latest_template = """cask "olovebar" do
  version :latest
  sha256 "{sha256}"

  url "https://codeberg.org/{owner}/{repo}/releases/download/latest/OLoveBar.dmg"
  name "OLoveBar"
  desc "Menu bar utility"
  homepage "https://codeberg.org/{owner}/{repo}"

  postflight do
    if File.exist?("#{{staged_path}}/OLoveBar.app")
      system "xattr", "-r", "-d", "com.apple.quarantine", "#{{staged_path}}/OLoveBar.app"
    end

    if File.exist?("#{{appdir}}/OLoveBar.app")
      system "xattr", "-r", "-d", "com.apple.quarantine", "#{{appdir}}/OLoveBar.app"
    end
  end

  app "OLoveBar.app", target: "#{{appdir}}/OLoveBar.app"

  uninstall quit: "com.sacrilege.olovebar"

  zap trash: [
    "~/Library/Preferences/com.sacrilege.olovebar.plist",
    "~/Library/Application Support/OLoveBar",
  ]
end
""".format(sha256=sha256, owner=owner, repo=repo)

    versioned_path.write_text(versioned_template, encoding="utf-8")
    latest_path.write_text(latest_template, encoding="utf-8")

    print(f"✅ Wrote {versioned_path}")
    print(f"✅ Wrote {latest_path}")


def git_commit_and_push(tap_dir: Path, version: str) -> None:
    """Run git add/commit/push inside the tap repo directory."""
    print(f"Running git add/commit/push in {tap_dir}...")

    def run(cmd: list[str], allow_failure: bool = False) -> None:
        result = subprocess.run(
            cmd,
            cwd=tap_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if result.stdout.strip():
            print(result.stdout.rstrip())
        if result.returncode != 0:
            if allow_failure:
                # Most common benign case: nothing to commit.
                print(f"(ignored) {' '.join(cmd)} failed with code {result.returncode}:")
                if result.stderr.strip():
                    print(result.stderr.rstrip())
            else:
                print(f"ERROR: {' '.join(cmd)} failed with code {result.returncode}:", file=sys.stderr)
                if result.stderr.strip():
                    print(result.stderr.rstrip(), file=sys.stderr)
                sys.exit(result.returncode)

    run(["git", "add", "."], allow_failure=False)
    run(["git", "commit", "-m", f"Update OLoveBar to version {version}"], allow_failure=True)
    run(["git", "push"], allow_failure=False)
    print("✅ Pushed changes to remote.")


def main() -> None:
    tap_env = os.getenv("TAP_DIR")
    if not tap_env:
        print("ERROR: TAP_DIR environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    tap_dir = Path(tap_env).expanduser().resolve()
    if not tap_dir.exists():
        print(f"ERROR: tap-dir {tap_dir} does not exist.", file=sys.stderr)
        sys.exit(1)

    dmg_path = Path(".build/OLoveBar.dmg")

    owner = os.getenv("CODEBERG_OWNER", "sacrilegewastaken")
    repo = os.getenv("CODEBERG_REPO", "olovebar")

    version = read_version()
    sha_hex = sha256_hex(dmg_path)

    print(f"Version: {version}")
    print(f"DMG: {dmg_path}")
    print(f"sha256: {sha_hex}")

    write_casks(tap_dir, version, sha_hex, owner=owner, repo=repo)
    git_commit_and_push(tap_dir, version)


if __name__ == "__main__":
    main()

