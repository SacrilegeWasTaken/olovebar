{
  description = "Flake to build OLoveBar on macOS by running `make bundle` and producing an .app in the Nix output";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        stdenv = pkgs.stdenv;
        isDarwin = builtins.match "*-darwin" system != null;
      in
      {
        packages = {
          olovebar = stdenv.mkDerivation rec {
            pname = "OLoveBar";
            version = "0.0.1";
            src = ./.;

            # Minimal build deps; the host still needs Xcode/CLT for AppKit frameworks.
            # We include `mas` in nativeBuildInputs to make it available in a dev shell,
            # but Xcode must be installed on the host (cannot be installed automatically
            # inside a Nix build). App Store id for Xcode is 497799835.
            buildInputs = [ pkgs.swift pkgs.uv ];
            nativeBuildInputs = [ pkgs.gnumake pkgs.mas ];

            buildPhase = ''
              set -euo pipefail
              echo "Checking for Xcode Command Line Tools (CLT) on host..."

              # Prefer Command Line Tools (sufficient for many builds). Detect via xcode-select.
              if command -v xcode-select >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
                echo "Found Xcode/CLT via xcode-select: $(xcode-select -p)"
              else
                echo "ERROR: Xcode Command Line Tools not found on host." >&2
                echo "Install them interactively with:" >&2
                echo "  xcode-select --install" >&2
                echo "For non-interactive / CI installs you can download the Command Line Tools package from Apple's developer site and install with:" >&2
                echo "  sudo installer -pkg /path/to/Command_Line_Tools.pkg -target /" >&2
                echo "If you prefer full Xcode, install from the App Store or via mas: mas install 497799835" >&2
                exit 1
              fi

              echo "Running make bundle to produce .app bundle (expects Makefile in repo)"
              make bundle
            '';

            installPhase = ''
              set -euo pipefail
              echo "Installing .build/OLoveBar.app into $out/Applications"
              mkdir -p $out/Applications
              if [ -d ".build/OLoveBar.app" ]; then
                ditto ".build/OLoveBar.app" "$out/Applications/OLoveBar.app"
                echo "Copied .build/OLoveBar.app -> $out/Applications/OLoveBar.app"
              else
                echo "ERROR: .build/OLoveBar.app not found (make bundle must produce it)" >&2
                exit 1
              fi
            '';

            # prevent accidental cross-platform builds
            meta = with pkgs.lib; {
              description = "OLoveBar macOS menu bar application (built with make bundle)";
              platforms = [ "darwin" ];
            };
          };
        };

        # default package for this flake
        defaultPackage = packages.olovebar;
      }
    );
}