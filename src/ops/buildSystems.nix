# Use of {vars,...} unpacking syntax causes infinite recursion; inherit later instead
self: super: let
  inherit (self) addNativeBuildInputs;

  buildWith = buildSystemOrSystems:
    addNativeBuildInputs
    (
      if builtins.isList buildSystemOrSystems
      then buildSystemOrSystems
      else [buildSystemOrSystems]
    );

  withBuildSystem = rec {
    flitCore = buildWith "flit-core";
    flit = flitCore;
    hatchling = buildWith "hatchling";
    scikitBuild = buildWith "scikit-build";
    scikitBuildCore = buildWith "scikit-build-core";
    setuptools = buildWith "setuptools";
    setupTools = setuptools;
  };
in {
  inherit buildWith withBuildSystem;
}
