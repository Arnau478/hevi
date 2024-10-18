{
  description = "Hevi hex viewer flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-deps-fod.url = "github:water-sucks/zig-deps-fod";
  };

  outputs = { nixpkgs, flake-utils, zig-deps-fod, ... }: flake-utils.lib.eachDefaultSystem(system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = rec {
        hevi = pkgs.callPackage ./nix/default.nix { inherit (zig-deps-fod.lib) fetchZigDeps; };
        default = hevi;
      };

      devShells.default = pkgs.mkShellNoCC {
        packages = with pkgs; [ zig ];
      };
    }
  );
}
