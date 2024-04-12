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
    addLibstdcpp
    addNixBuildInputs
    addPatchelfSearchPath
    withLowPriority
    multi
    substitute
    withCudaBaseLibraries
    withCudaInputs
    ;

  coreOverrides = {
    # `wheel` seems to often end up in scenarios where it clashes with itself.
    # Just mark it as low-priority in merges, since it's build-time-only,
    # and we don't care which version survives the final merge.
    wheel = withLowPriority;
  };

  cudaOverridesFor = {
    selectCudaPackages,
    cudaSuffix ? "cu12", # The minor version numbers are not included in the upstream nvidia pypi packages
  }: let
    withCudaNative = cudaDepPkg:
      multi [
        withCudaBaseLibraries
        (substitute
          (operationArgs: (selectCudaPackages operationArgs).${cudaDepPkg}))
      ];
  in {
    # Substitute these packages with the nix-native CUDA versions, as the python packages are nothing more than the wrong native files
    "nvidia-cublas-${cudaSuffix}" = withCudaNative "libcublas";
    "nvidia-cuda-cupti-${cudaSuffix}" = withCudaNative "cuda_cupti";
    "nvidia-cuda-nvrtc-${cudaSuffix}" = withCudaNative "cuda_nvrtc";
    "nvidia-cuda-runtime-${cudaSuffix}" = withCudaNative "cuda_cudart";
    "nvidia-cudnn-${cudaSuffix}" = withCudaNative "cudnn";
    "nvidia-cufft-${cudaSuffix}" = withCudaNative "libcufft";
    "nvidia-curand-${cudaSuffix}" = withCudaNative "libcurand";
    "nvidia-cusolver-${cudaSuffix}" = withCudaNative "libcusolver";
    "nvidia-cusparse-${cudaSuffix}" = withCudaNative "libcusparse";
    "nvidia-nccl-${cudaSuffix}" = withCudaNative "nccl";
    "nvidia-nvtx-${cudaSuffix}" = withCudaNative "cuda_nvtx";
  };

  cudaOverrides = cudaOverridesFor {
    selectCudaPackages = operationArgs: operationArgs.final.pkgs.cudaPackages_12_3;
  };

  torchOverrides = let
    # Adds Torch native binaries, FFmpeg, and SoX, and adds them to the search path for auto-patchelf
    withLibTorch = multi [
      (addPatchelfSearchPath [
        "torch"
        ({final, ...}: final.pkgs.ffmpeg_6-headless.lib)
        ({final, ...}: final.pkgs.ffmpeg_5-headless.lib)
        ({final, ...}: final.pkgs.ffmpeg_4-headless.lib)
      ])
      (addNixBuildInputs [
        # Torch tries to build for all 3 of these versions of FFMPEG by default
        "ffmpeg_4-headless"
        "ffmpeg_5-headless"
        "ffmpeg_6-headless"
        ({final, ...}: final.pkgs.sox.lib)
      ])
    ];
  in {
    torch = multi [
      withCudaInputs
      (addBuildInputs ["filelock" "jinja2" "networkx" "sympy"])
      (addLibstdcpp "libtorch_global_deps.so")
    ];
    torchvision = multi [
      withCudaInputs
      (addBuildInputs ["filelock" "jinja2" "networkx" "sympy"])
      (addLibstdcpp "libtorch_global_deps.so")
      withLibTorch
    ];
    torchaudio = multi [
      withCudaInputs
      (addBuildInputs [
        "filelock"
        "jinja2"
        "networkx"
        "sympy"
        "torch"
        ({final, ...}: final.pkgs.lib.getLib final.torch)
      ])
      (addLibstdcpp "libtorch_global_deps.so")
      withLibTorch
    ];
  };

  overrides = coreOverrides // torchOverrides // cudaOverrides;
in {
  inherit overrides coreOverrides cudaOverrides torchOverrides;
}
