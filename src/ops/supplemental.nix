# Use of {vars,...} unpacking syntax causes infinite recursion; inherit later instead
self: super: let
  inherit (self) resolveDep;

  # Marks outputs from a package as low-priority when checking for conflicts in
  # outputs, making it such that any normal-priority package will not conflict.
  # The files from the higher-priority package will take precedence in outputs.
  lowPri = {
    pkg,
    final,
    ...
  }:
    final.lib.meta.lowPrio pkg;

  # Replace the given package with the resolution of `dep`; equivalent to a flip of resolveDep.
  substitute = dep: {final, ...} @ args: resolveDep args dep;
in {
  inherit lowPri substitute;
}
