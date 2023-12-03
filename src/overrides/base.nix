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
    addNativeBuildInputs
    addNixBuildInputs
    addPatchelfSearchPath
    llamaCppUseLlamaBuild
    lowPri
    multi
    preferWheel
    substitute
    withCudaBaseLibraries
    withCudaInputs
    ;

  coreOverrides = {
    # `wheel` seems to often end up in scenarios where it clashes with itself.
    # Just mark it as low-priority in merges, since it's build-time-only,
    # and we don't care which version survives the final merge.
    wheel = lowPri;
  };

  cudaOverrides = let
    withCudaNative = cudaDepPkg:
      multi [
        withCudaBaseLibraries
        (substitute
          ({final, ...}: final.pkgs.cudaPackages_12_2.${cudaDepPkg}))
      ];
  in {
    # Substitute these packages with the nix-native CUDA 12.2 versions, as the python packages are nothing more than the wrong native files
    nvidia-cublas-cu12 = withCudaNative "libcublas";
    nvidia-cuda-cupti-cu12 = withCudaNative "cuda_cupti";
    nvidia-cuda-nvrtc-cu12 = withCudaNative "cuda_nvrtc";
    nvidia-cuda-runtime-cu12 = withCudaNative "cuda_cudart";
    nvidia-cudnn-cu12 = withCudaNative "cudnn";
    nvidia-cufft-cu12 = withCudaNative "libcufft";
    nvidia-curand-cu12 = withCudaNative "libcurand";
    nvidia-cusolver-cu12 = withCudaNative "libcusolver";
    nvidia-cusparse-cu12 = withCudaNative "libcusparse";
    nvidia-nccl-cu12 = withCudaNative "nccl";
    nvidia-nvtx-cu12 = withCudaNative "cuda_nvtx";
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
