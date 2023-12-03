localFlake: {...}: let
  overlay = final: prev: let
    mlOverride = final.callPackage ../default.nix {};
  in {theseus = {inherit mlOverride;};};
in {
  flake.overlays.default = overlay;
  perSystem = {pkgs, ...}: {
    packages.default =
      pkgs.runCommandWith
      {
        name = "MLOverride";
        runLocal = true;
        derivationArgs = {
          version = "0.0.1";
          passthru = {
            inherit overlay; # Using passthru means that the pseudo-derivation need not be built at all
          };
        };
      } ''
        echo "Theseus MLOverride pseudo-derivation for Flake outputs" > $out
      '';
  };
}
