{lib ? (import <nixpkgs> {}).lib, ...}: let
  core = import ./core.nix {
    inherit lib;
  };
  ops = import ./ops {
    inherit core;
  };
  overrides = import ./overrides {
    inherit core ops;
  };
in {
  inherit core;
  inherit (core) mergeOverrides buildOpsOverlay;
  inherit ops;
  inherit overrides;
}
