{
  stdenvNoCC,
  zig,
  fetchZigDeps,
  lib,
  commit_id,
}: stdenvNoCC.mkDerivation {
  pname = "hevi";
  version = "2.0.0";
  src = lib.sources.cleanSourceWith {
    filter = name: type: !(lib.strings.hasSuffix ".nix" (baseNameOf (toString name)));
    src = lib.sources.cleanSource ../.;
  };

  nativeBuildInputs = [ zig.hook ];
  
  enablePararellBuilding = true;

  zigBuildFlags = "-Dversion_commit_id=${commit_id} -Dversion_commit_num=0";

  postPatch = let 
    deps = fetchZigDeps {
      inherit zig;
      stdenv = stdenvNoCC;

      name = "hevi";
      src = ../.;
      depsHash = "sha256-B3ps6AfYdcbSNiVuhJQWrjHxknoKmYL8jdbBVr4lINY=";
    };
  in
  ''
    ln -s ${deps} $ZIG_GLOBAL_CACHE_DIR/p
  '';

  meta = with lib; {
    description = "A modern hex viewer";

    homePage = "https://arnau478.github.io/hevi/";
    license = licenses.gpl3Plus;
    platforms = platforms.all;
  };
}
