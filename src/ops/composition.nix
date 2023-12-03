# Heavily modified from LMQL's source, which is licensed under the Apache 2.0 license.
# See https://github.com/eth-sri/lmql/blob/76abda8875e82ae0269ef93e63c8205125976fbb/scripts/flake.d/overrides.nix for the original source.
#
# Changes made include the addition of several operation types, and the export rather than
# direct invocation of the override set and its overlay transform.
# Further packages have been added or modified to support scenarios involving Cuda 12.2 with PyTorch.
_: _: let
  # Compose two operations
  composeOpPair = opLeft: opRight: {
    name,
    final,
    prev,
    pkg, # TODO: Remove after refactor completion
    ...
  } @ argsIn: let
    firstResult = opLeft argsIn;
  in
    opRight {
      inherit name final;
      prev = prev // {"${name}" = firstResult;};
      pkg = firstResult;
    };

  # Definition of a no-op in operational composition
  composeIdentity = {pkg, ...}: pkg;

  # Compose multiple operations in sequence
  multi = builtins.foldl' composeOpPair composeIdentity;
in {
  # Composition of "operations", which are functions taking an attrset of
  # overlay-like parameters and returning a package with the overlays applied.
  #
  # The operations are composed left-to-right, so the last operation takes
  # precedence when an operation mutates or replaces an existing value.
  #
  # Operations are evaluated in terms of eachother within a submission.
  inherit multi composeOpPair composeIdentity;
}
