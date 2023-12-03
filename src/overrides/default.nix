args: let
  base = import ./base.nix args;
  miscOverrides = import ./misc.nix args;
in
  base
  // {
    miscOverrides = miscOverrides;
  }
