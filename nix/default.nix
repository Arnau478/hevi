{
  stdenvNoCC,
  zig,
  callPackage,
  lib
}: stdenvNoCC.mkDerivation {
  pname = "hevi";
  version = "2.0.0";
  src = lib.sources.cleanSourceWith {
    filter = name: type: !(lib.strings.hasSuffix ".nix" (baseNameOf (toString name)));
    src = lib.sources.cleanSource ../.;
  };

  nativeBuildInputs = [ zig.hook ];
  
  enablePararellBuilding = true;

  postPatch = ''
    ln -s ${callPackage ./deps.nix { }} $ZIG_GLOBAL_CACHE_DIR/p
  '';
}
