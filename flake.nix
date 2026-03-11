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
    latestHash    = "sha256-Gbo06XwLbPuyTzjaJktUGSlAp7RUWw0ha7DHR6i3WSU=";
  in {
    packages.${system} = {
      olovebar = mkOlovebar {
        version = latestVersion;
        sha256  = latestHash;
      };

      olovebar_1_2_0 = mkOlovebar {
        version = "1.2.0";
        sha256  = "sha256-vypgvCrjMDuMRcGtzEzNiryHkmYHmYmJ/FNGkJ2ayP4=";
      };

      olovebar_1_3_0 = mkOlovebar {
        version = "1.3.0";
        sha256  = "sha256-kjKN23/dBQblEVGo+ySwx+WUmqetGcVDR87t48Wmo6c=";
      };

      olovebar_1_3_1 = mkOlovebar {
        version = "1.3.1";
        sha256  = "sha256-xZW+zdDMMNK3ylvYmdWqX3RQP6mrS+2E9BsGsOhe1a8=";
      };

      olovebar_1_3_2 = mkOlovebar {
        version = "1.3.2";
        sha256  = "sha256-Gbo06XwLbPuyTzjaJktUGSlAp7RUWw0ha7DHR6i3WSU=";
      };
    };

    # чтобы nix сам понимал, кто тут главный
    packages.${system}.default = self.packages.${system}.olovebar;
  };
}