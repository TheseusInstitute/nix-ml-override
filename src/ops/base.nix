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

  resolveDep = {final, ...} @ args: (dep:
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
  addBuildInputs = extraBuildInputs: {pkg, ...} @ args:
    pkg.overridePythonAttrs (old: {
      buildInputs =
        (old.buildInputs or [])
        ++ (map (resolveDep args) extraBuildInputs);
    });

  addNixBuildInputs = extraBuildInputs: {
    final,
    pkg,
    ...
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
    final,
    pkg,
    ...
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
  addNativeBuildInputs = extraBuildInputs: {pkg, ...} @ args:
    pkg.overridePythonAttrs (old: {
      nativeBuildInputs =
        (old.nativeBuildInputs or [])
        ++ (map (resolveDep args) extraBuildInputs);
    });

  addNixNativeBuildInputs = extraNativeBuildInputs: {
    final,
    pkg,
    ...
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
    final,
    pkg,
    ...
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

  addPatchelfSearchPath = libSearchPathDeps: operationArgs:
    multi [
      (addPatchelfSearchPathInner libSearchPathDeps)
      (addNixNativeBuildInputs ["autoPatchelfHook"])
    ]
    operationArgs;

  withCudaBaseLibraries = {final, ...} @ args:
    (addBuildInputs (with final.pkgs.cudaPackages_12_2; [
      cuda_cccl
      cuda_cccl.dev
      cuda_cudart
      cuda_cupti
      cuda_nvcc
      cuda_nvcc.dev
      cuda_nvrtc
      cuda_nvprof
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

  # Use the libllama.dylib or libllama.so from llamaDotCpp instead of letting the package build its own
  llamaCppUseLlamaBuild = {final, ...} @ operationArgs:
    if !(final.pkgs ? "llama-cpp")
    then
      builtins.abort
      "llama-cpp must be available in order to use llama-cpp-python"
    else
      multi [
        ({
          final,
          pkg,
          ...
        }:
          pkg.overridePythonAttrs (old: {
            cmakeFlags = (old.cmakeFlags or []) ++ ["-DLLAMA_CUBLAS=ON"];
            env =
              (old.env or {})
              // {
                # Skip building the binaries- we already have them thanks to final.pkgs.llama-cpp.
                # Also inform CMake that we're using CUBLAS, in case the author adds reliance on that.
                #
                # We are allowing scikit-build to actually perform the build, so the derivation
                # argument "cmakeFlags" is not appropriate in this circumstance.
                CMAKE_ARGS = "-DLLAMA_BUILD=OFF -DLLAVA_BUILD=OFF -DLLAMA_CUBLAS=ON";
                CUDAToolkit_ROOT = "${final.pkgs.cudaPackages_12_2.cudatoolkit}";
              };
            catchConflicts = false;
            # llama_cpp_python's `_load_shared_library` uses `__file__` to find the directory for `libllama.so`.
            # We also include it in the library directory for this package in case something else inherits the dep.
            postFixup =
              (old.postFixup or "")
              + (with final.pkgs; ''
                ln -s ${lib.getLib llama-cpp}/lib/* $out/lib/
                ln -s ${lib.getLib llama-cpp}/lib/* $out/${python.sitePackages}/llama_cpp/
              '');
            propagatedBuildInputs =
              (old.propagatedBuildInputs or [])
              ++ (with final.pkgs; [
                llama-cpp
                (lib.getLib llama-cpp)
              ]);
            nativeBuildInputs =
              (old.nativeBuildInputs or [])
              ++ (with final.pkgs; [
                pkg-config
                llama-cpp
                (lib.getLib llama-cpp)
                git
                llama-cpp.passthru.cudaToolkit
              ]);
          }))
        withCudaBaseLibraries
      ]
      operationArgs;
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
