{ stdenv, fetchurl }:

stdenv.mkDerivation {
  pname = "olovebar";
  version =
    lib.strings.trim (builtins.readFile ./VERSION);

  src = fetchurl {
    url = "https://codeberg.org/sacrilegewastaken/olovebar/releases/download/${version}/OLoveBar.dmg";
    sha256 = "sha256-xZW+zdDMMNK3ylvYmdWqX3RQP6mrS+2E9BsGsOhe1a8=";
  };

  installPhase = ''
    mkdir -p $out/Applications
    hdiutil attach "$src" -mountpoint /Volumes/OLoveBar -nobrowse -quiet
    cp -R "/Volumes/OLoveBar/OLoveBar.app" "$out/Applications/OLoveBar.app"
    hdiutil detach "/Volumes/OLoveBar" -quiet
  '';
}