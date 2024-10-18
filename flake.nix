{
  description = "Hevi hex viewer flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem(system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = rec {
        hevi = pkgs.callPackage ./nix/default.nix {};
        default = hevi;
      };

      devShells.default = pkgs.mkShellNoCC {
        packages = with pkgs; [ zig ];
      };
    }
  );
}
