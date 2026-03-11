{
  description = "OLoveBar - macOS menu bar companion (SwiftPM) - Nix flake (aarch64-darwin only)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.olovebar = pkgs.stdenv.mkDerivation {
          __noChroot = true;

          pname = "olovebar";
          version = "1.3.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.python3 ];

          buildPhase = ''
            # Пробрасываем системные пути macOS, чтобы найти xcode-select и swift
            export PATH=$PATH:/usr/bin:/usr/sbin:/usr/local/bin
            
            # Теперь эти команды сработают
            export DEVELOPER_DIR=$(xcode-select -p)
            export SDKROOT=$(xcrun --show-sdk-path)
            
            echo "Using SDK at: $SDKROOT"
            
            # Запускаем сборку
            swift build -c release
            
            # Упаковка
            python3 Script/Bundle.py .build/release/olovebar .build/OLoveBar.app com.sacrilege.olovebar
          '';

          installPhase = ''
            mkdir -p $out/Applications
            cp -R .build/OLoveBar.app $out/Applications/OLoveBar.app
          '';
        };

        packages.default = self.packages.${system}.olovebar;

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.makeWrapper
            pkgs.pkg-config
            pkgs.python3
          ];
        };
      });
}

