{
  description = "OLoveBar — несколько версий по феншую";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }: let
    system = "aarch64-darwin";
    pkgs   = import nixpkgs { inherit system; };
    lib    = pkgs.lib;

    mkOlovebar = { version, sha256 }: pkgs.stdenv.mkDerivation {
      pname   = "olovebar";
      inherit version;

      src = pkgs.fetchurl {
        url    = "https://codeberg.org/sacrilegewastaken/olovebar/releases/download/${version}/OLoveBar.dmg";
        inherit sha256;
      };

      installPhase = ''
        mkdir -p $out/Applications
        hdiutil attach "$src" -mountpoint /Volumes/OLoveBar -nobrowse -quiet
        cp -R "/Volumes/OLoveBar/OLoveBar.app" "$out/Applications/OLoveBar.app"
        hdiutil detach "/Volumes/OLoveBar" -quiet
      '';
    };

    latestVersion = lib.strings.trim (builtins.readFile ./VERSION);
    latestHash    = "sha256-bx11T5df1VHOD+dVoAFBDx9fdvtwukd46Hk9gF+4yOk=";
  in {
    packages.${system} = {
      olovebar = mkOlovebar {
        version = latestVersion;
        sha256  = latestHash;
      };

      olovebar_0_3_5 = mkOlovebar {
        version = "0.3.5";
        sha256  = "sha256-bx11T5df1VHOD+dVoAFBDx9fdvtwukd46Hk9gF+4yOk=";
      };
    };

    # чтобы nix сам понимал, кто тут главный
    packages.${system}.default = self.packages.${system}.olovebar;
  };
}