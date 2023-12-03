# Produces a composite of multiple pseudo-overlays containing the various operations made available to overrides
# This is handled by fixed-point convergence of a set of final-parameter-only overlays
{core, ...}: let
  composition = import ./composition.nix;
  base = import ./base.nix;
  buildSystems = import ./buildSystems.nix;
  supplemental = import ./supplemental.nix;
  opSets = [
    composition
    base
    buildSystems
    supplemental
    (_: _: {inherit core ops;})
  ];
  composedOps = core.composeOverlays opSets;
  ops = core.fixComposition composedOps;
in
  ops
