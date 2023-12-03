# MLOverride

Provides overlays for Machine Learning in Nix.

## Usage:

### In `flake.nix`:
```nix
inputs = {
  # ...
  mlOverride = {
    url = "github:TheseusInstitute/nix-ml-override/main";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

# ...

# During nixpkgs overlayed import (See flake-parts documentation if needed):
nixpkgs = import inputs.nixpkgs {
  inherit system;
  overlays = [
    (inputs.poetry2nix.overlay or inputs.poetry2nix.overlays.default)
    (inputs.mlOverride.overlay or inputs.mlOverride.overlays.default)
  ];
  # config = { ... };
};

# pkgs.theseus.mlOverride is now available for poetry, and overlays for ML compatibility are applied.
```

### In Poetry2Nix
```nix
inherit (pkgs.theseus) mlOverride;
overrideSelections = mlOverride.mergeOverrides (with mlOverride.overrides; [
  coreOverrides
  cudaOverrides
  torchOverrides
  miscOverrides
]);
mlOverrideOverlay = mlOverride.buildOpsOverlay overrideSelections;

myEnv = pkgs.poetry2nix.mkPoetryEnv {
  projectDir = ./.;
  overrides = pkgs.poetry2nix.overrides.withDefaults mlOverrideOverlay;
  editablePackageSources = {
    # ...
  };
};
```

