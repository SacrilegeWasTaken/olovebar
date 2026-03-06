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

        swiftToolchain = with pkgs; [ swift swiftpm ];
      in
      {
        packages.olovebar = pkgs.stdenv.mkDerivation {
          pname = "olovebar";
          version = "1.3.0";

          src = ./.;

          nativeBuildInputs = swiftToolchain ++ [ pkgs.python3 ];

          buildPhase = ''
            swift build -c release
            python3 Script/Bundle.py .build/release/olovebar .build/OLoveBar.app com.sacrilege.olovebar
          '';

          installPhase = ''
            mkdir -p $out/Applications
            cp -R .build/OLoveBar.app $out/Applications/OLoveBar.app
          '';
        };

        packages.default = self.packages.${system}.olovebar;

        devShells.default = pkgs.mkShell {
          buildInputs = swiftToolchain ++ [
            pkgs.makeWrapper
            pkgs.pkg-config
            pkgs.python3
          ];
        };
      });
}

