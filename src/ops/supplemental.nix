# Use of {vars,...} unpacking syntax causes infinite recursion; inherit later instead
self: super: let
  inherit (self) resolveDep;

  # Marks outputs from a package as low-priority when checking for conflicts in
  # outputs, making it such that any normal-priority package will not conflict.
  # The files from the higher-priority package will take precedence in outputs.
  withLowPriority = {
    pkg,
    final,
    ...
  }:
    final.lib.meta.lowPrio pkg;

  # Replace the given package with the resolution of `dep`; equivalent to a flip of resolveDep.
  substitute = dep: {final, ...} @ args: resolveDep args dep;

  # Adds a breakpoint on the arguments upon any attempt to resolve the package.
  # Argument content differs depending on the ordering of the override operations.
  withPackageDebugBreak = args: builtins.seq (builtins.break args) args.pkg;
in {
  inherit
    substitute
    withLowPriority
    withPackageDebugBreak
    ;
}
