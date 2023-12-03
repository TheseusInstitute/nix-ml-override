{lib, ...}: let
  implementation = import ./src/default.nix {
    inherit lib;
  };
in
  implementation
