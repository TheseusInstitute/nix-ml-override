# Heavily modified from LMQL's source, which is licensed under the Apache 2.0 license.
# See https://github.com/eth-sri/lmql/blob/76abda8875e82ae0269ef93e63c8205125976fbb/scripts/flake.d/overrides.nix for the original source.
#
# Changes made include the addition of several operation types, and the export rather than
# direct invocation of the override set and its overlay transform.
# Further packages have been added or modified to support scenarios involving Cuda 12.2 with PyTorch.
#
# Use of {vars,...} unpacking syntax causes infinite recursion; inherit later instead
self: super: let
  inherit (builtins) map;
  inherit (self) multi;

  resolveDep = {
    name,
    final,
    prev,
    pkg,
    ...
  } @ args: (dep:
    if builtins.isString dep
    then builtins.getAttr dep final
    else if builtins.isFunction dep
    then (dep args)
    else dep);

  # Applies a function directly to the input package, without operational context
  withPackage = f: {pkg, ...}: f pkg;

  # Prefer the wheel version of a package over the source version, bypassing some issues in nixification.
  preferWheel = withPackage (pkg: pkg.override {preferWheel = true;});

  # Add extra inputs needed to build from source; often things like setuptools or hatchling not included upstream
  addBuildInputs = extraBuildInputs: {
    name,
    final,
    prev,
    pkg,
  } @ args:
    pkg.overridePythonAttrs (old: {
      buildInputs =
        (old.buildInputs or [])
        ++ (map (resolveDep args) extraBuildInputs);
    });

  addNixBuildInputs = extraBuildInputs: {
    name,
    final,
    prev,
    pkg,
  } @ args:
    pkg.overridePythonAttrs (old: {
      buildInputs =
        (old.buildInputs or [])
        ++ (map
          (dep:
            if builtins.isFunction dep
            then (resolveDep args dep)
            else (final.pkgs."${dep}"))
          extraBuildInputs);
    });

  # Not sure what pytorch is doing such that its libtorch_global_deps.so dependency on libstdc++ isn't detected by autoPatchelfFixup, but...
  addLibstdcpp = libToPatch: {
    name,
    final,
    prev,
    pkg,
  }:
    if final.pkgs.stdenv.isDarwin
    then
      pkg.overridePythonAttrs
      (old: {
        postFixup =
          (old.postFixup or "")
          + ''
            while IFS= read -r -d "" tgt; do
              cmd=( ${final.pkgs.patchelf}/bin/patchelf --add-rpath ${final.pkgs.stdenv.cc.cc.lib}/lib --add-needed libstdc++.so "$tgt" )
              echo "Running: ''${cmd[*]@Q}" >&2
              "''${cmd[@]}"
            done < <(find "$out" -type f -name ${
              final.pkgs.lib.escapeShellArg libToPatch
            } -print0)
          '';
      })
    else pkg;

  # Add extra build-time inputs needed to build from source
  addNativeBuildInputs = extraBuildInputs: {
    name,
    final,
    prev,
    pkg,
  } @ args:
    pkg.overridePythonAttrs (old: {
      nativeBuildInputs =
        (old.nativeBuildInputs or [])
        ++ (map (resolveDep args) extraBuildInputs);
    });

  addNixNativeBuildInputs = extraNativeBuildInputs: {
    name,
    final,
    prev,
    pkg,
  } @ args:
    pkg.overridePythonAttrs (old: {
      # nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ (map (dep: (final.pkgs."${dep}")) extraNativeBuildInputs);
      nativeBuildInputs =
        (old.nativeBuildInputs or [])
        ++ (map
          (dep:
            if builtins.isFunction dep
            then (resolveDep args dep)
            else (final.pkgs."${dep}"))
          extraNativeBuildInputs);
    });

  addPatchelfSearchPathInner = libSearchPathDeps: {
    name,
    final,
    prev,
    pkg,
  } @ args: let
    opsForDep = dep: ''
      while IFS= read -r -d "" dir; do
        echo "Adding $dir to patchelf search path for ${
        (resolveDep args dep).name
      }" >&2
        addAutoPatchelfSearchPath "$dir"
      done < <(find ${
        resolveDep args dep
      } -type f -name 'lib*.so' -printf '%h\0' | sort -zu)
    '';
  in
    pkg.overridePythonAttrs (old: {
      prePatch =
        (old.prePatch or "")
        + (final.pkgs.lib.concatLines (map opsForDep libSearchPathDeps));
    });

  addPatchelfSearchPath = libSearchPathDeps: {
    name,
    final,
    prev,
    pkg,
  } @ args:
    multi [
      (addPatchelfSearchPathInner libSearchPathDeps)
      (addNixNativeBuildInputs ["autoPatchelfHook"])
    ]
    args;

  # Use the libllama.dylib or libllama.so from llamaDotCpp instead of letting the package build its own
  llamaCppUseLlamaBuild = {
    name,
    final,
    prev,
    pkg,
  }:
    if !(final.pkgs ? "llama-cpp")
    then
      builtins.abort
      "llama-cpp must be available in order to use llama-cpp-python"
    else
      (pkg.overridePythonAttrs (old: {
        cmakeFlags = (old.cmakeFlags or []) ++ ["-DLLAMA_CUBLAS=1"];
        catchConflicts = false;
        buildInputs = (old.buildInputs or []) ++ [final.pkgs.openblas];
        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ (with final.pkgs; [openblas pkg-config]);
      }));

  withCudaBaseLibraries = {final, ...} @ args:
    (addBuildInputs (with final.pkgs.cudaPackages_12_2; [
      cuda_cudart
      cuda_cupti
      cuda_nvrtc
      cuda_nvtx
      cudnn
      nccl
      libcublas
      libcufft
      libcurand
      libcusparse
      libcusolver
      libnvjitlink
    ]))
    args;

  withCudaInputs = {final, ...} @ args:
    (multi [
      (addBuildInputs (with final; [
        nvidia-cublas-cu12
        nvidia-cuda-cupti-cu12
        nvidia-cuda-nvrtc-cu12
        nvidia-cuda-runtime-cu12
        nvidia-cudnn-cu12
        nvidia-cufft-cu12
        nvidia-curand-cu12
        nvidia-cusolver-cu12
        nvidia-cusparse-cu12
        nvidia-nccl-cu12
        nvidia-nvtx-cu12
        triton
      ]))
      withCudaBaseLibraries
    ])
    args;
in {
  inherit resolveDep;

  inherit
    addBuildInputs
    addLibstdcpp
    addNativeBuildInputs
    addNixBuildInputs
    addNixNativeBuildInputs
    addPatchelfSearchPath
    llamaCppUseLlamaBuild
    preferWheel
    withCudaBaseLibraries
    withCudaInputs
    withPackage
    ;
}
