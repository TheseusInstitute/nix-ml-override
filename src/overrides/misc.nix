# Heavily modified from LMQL's source, which is licensed under the Apache 2.0 license.
# See https://github.com/eth-sri/lmql/blob/76abda8875e82ae0269ef93e63c8205125976fbb/scripts/flake.d/overrides.nix for the original source.
#
# Changes made include the addition of several operation types, and the export rather than
# direct invocation of the override set and its overlay transform.
# Further packages have been added or modified to support scenarios involving Cuda 12.2 with PyTorch.
{ops, ...}: let
  inherit
    (ops)
    addBuildInputs
    addNativeBuildInputs
    addPatchelfSearchPath
    buildWith
    llamaCppUseLlamaBuild
    multi
    preferWheel
    withBuildSystem
    withCudaInputs
    ;

  # TODO: Port the majority of these to nickel-produced YAML/JSON/TOML by building a DSL.
  miscOverrides = {
    accelerate = multi [
      withCudaInputs
      (addBuildInputs ["filelock" "jinja2" "networkx" "sympy"])
      withBuildSystem.setuptools
    ];
    accessible-pygments = addNativeBuildInputs ["setuptools"];
    aiohttp-sse-client =
      multi
      [(addNativeBuildInputs ["pytest" "pytest-runner" "setuptools"])];
    auto-gptq = multi [
      preferWheel
      withCudaInputs
      (addPatchelfSearchPath ["torch"])
      withBuildSystem.setuptools
    ];
    cmake = multi [
      preferWheel
      withBuildSystem.setuptools
    ];
    llama-cpp-python = multi [
      llamaCppUseLlamaBuild
      withBuildSystem.scikitBuildCore
      (addBuildInputs ["diskcache"])
      (addNativeBuildInputs ["diskcache"])
      (addNativeBuildInputs [
        "pyproject-metadata"
        "pathspec"
      ])
    ];
    optimum = multi [withCudaInputs withBuildSystem.setuptools];
    pandas = addNativeBuildInputs ["versioneer" "tomli"];
    peft = withCudaInputs;
    pandoc = withBuildSystem.setuptools;
    pydata-sphinx-theme = preferWheel;
    rouge = withBuildSystem.setuptools;
    safetensors = preferWheel; # TODO: Nixify
    shibuya = withBuildSystem.setuptools;
    sphinx-book-theme = preferWheel;
    sphinx-theme-builder = withBuildSystem.flitCore;
    tiktoken = preferWheel; # TODO: Nixify
    tokenizers = preferWheel; # TODO: Nixify
    urllib3 = withBuildSystem.hatchling;
    pyarrow = buildWith ["hatchling" "flit-core"];
    pyarrow-hotfix = buildWith ["hatchling" "flit-core"];
    # pytorch-lightning = preferWheel; # TODO: pytorch-lighting overlay is broken; investigate
    typeshed-client = withBuildSystem.setuptools;
    jsonargparse = withBuildSystem.setuptools;
    gekko = withBuildSystem.setuptools;
    hydra = withBuildSystem.setuptools;
    hydra-core = multi [
      # TODO: Nixify
      preferWheel
      # (addNixNativeBuildInputs [ "jdk" ])
      # withBuildSystem.setuptools
    ];
    numpy = preferWheel;

    ## Tip: If you start needing these overrides, you should try to
    ##   wrap the overlay with `poetry2nix.overrides.withDefaults`.
    # absl-py = useSetupTools;
    # attrs = useHatchling;
    # certifi = useSetupTools;
    # charset-normalizer = useSetupTools;
    # dill = useSetupTools;
    # diskcache = useSetupTools;
    # frozenlist = useSetupTools;
    # humanfriendly = useSetupTools;
    # markupsafe = useSetupTools;
    # mpmath = useSetupTools;
    # packaging = useFlitCore;
    # protobuf = useSetupTools;
    # pytz = useSetupTools;
    # six = useSetupTools;
  };
in
  miscOverrides
