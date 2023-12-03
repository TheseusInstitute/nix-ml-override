# Heavily modified from LMQL's source, which is licensed under the Apache 2.0 license.
# See https://github.com/eth-sri/lmql/blob/76abda8875e82ae0269ef93e63c8205125976fbb/scripts/flake.d/overrides.nix for the original source.
#
# Changes made include the addition of several operation types, and the export rather than
# direct invocation of the override set and its overlay transform.
# Further packages have been added or modified to support scenarios involving Cuda 12.2 with PyTorch.
{
  lib, # Do not expose lib from core directly; minimize nixpkgs exposure
  ...
}: let
  inherit (builtins) mapAttrs;

  # Produces an overlay from an attrset of override operations
  buildOpsOverlay = overrides: (final: prev:
    mapAttrs
    (package: op: (op {
      inherit final prev;
      name = package;
      pkg = builtins.getAttr package prev;
    }))
    overrides);

  mergeOverrides = selection: builtins.foldl' (a: b: a // b) {} selection;

  # Combines a set of overlays (`self: super: { ... }`) into one with the same signature
  composeOverlays = lib.composeManyExtensions;

  # Applies a set of overlays to an empty set to produce the final overlayed composition via fixed-point logic
  # Equivalent to:
  # fixComposition = overlay: (lib.fixedPoints.makeExtensible (self: {})).extend overlay;
  fixComposition = overlay: lib.fix (lib.extends overlay (_: {}));
in {
  # Usage: `poetry2nix.overrides.withDefaults (buildOpsOverlay selectedOverrides)`
  inherit buildOpsOverlay;

  inherit mergeOverrides;

  inherit composeOverlays fixComposition;
}
