{
  description = "MLOverride enables modern Machine Learning in Nix";

  inputs = {
    nixpkgs = {url = "github:NixOS/nixpkgs/nixos-unstable";};
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs = {
        nixpkgs-lib.follows = "nixpkgs";
      };
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;}
    ({
      withSystem,
      flake-parts-lib,
      ...
    }: (
      let
        inherit (flake-parts-lib) importApply;
        flakeModules.mloverride =
          importApply ./modules/mlOverride.nix {inherit withSystem;};
      in {
        imports = [flakeModules.mloverride inputs.treefmt-nix.flakeModule];
        systems = [
          "x86_64-linux"
          # "aarch64-darwin" "x86_64-darwin" # TODO: Add darwin support
          # "aarch64-linux" # TODO: Add aarch64 Linux support
        ];
        perSystem = {...}: {
          treefmt = {
            flakeCheck = true;
            flakeFormatter = true;
            projectRootFile = "flake.nix";
            programs = {
              alejandra.enable = true;
              nickel.enable = true;
            };
          };
        };
        flake = {};
      }
    ));
}
