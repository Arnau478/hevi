# generated by zon2nix (https://github.com/Cloudef/zig2nix)

{ lib, linkFarm, fetchurl, fetchgit, runCommandLocal, zig, name ? "zig-packages" }:

with builtins;
with lib;

let
  unpackZigArtifact = { name, artifact }: runCommandLocal name {
      nativeBuildInputs = [ zig ];
    } ''
      hash="$(zig fetch --global-cache-dir "$TMPDIR" ${artifact})"
      mv "$TMPDIR/p/$hash" "$out"
      chmod 755 "$out"
    '';

  fetchZig = { name, url, hash }: let
    artifact = fetchurl { inherit url hash; };
  in unpackZigArtifact { inherit name artifact; };

  fetchGitZig = { name, url, hash }: let
    parts = splitString "#" url;
    url_base = elemAt parts 0;
    url_without_query = elemAt (splitString "?" url_base) 0;
    rev_base = elemAt parts 1;
    rev = if match "^[a-fA-F0-9]{40}$" rev_base != null then rev_base else "refs/heads/${rev_base}";
  in fetchgit {
    inherit name rev hash;
    url = url_without_query;
    deepClone = false;
  };

  fetchZigArtifact = { name, url, hash }: let
    parts = splitString "://" url;
    proto = elemAt parts 0;
    path = elemAt parts 1;
    fetcher = {
      "git+http" = fetchGitZig { inherit name hash; url = "http://${path}"; };
      "git+https" = fetchGitZig { inherit name hash; url = "https://${path}"; };
      http = fetchZig { inherit name hash; url = "http://${path}"; };
      https = fetchZig { inherit name hash; url = "https://${path}"; };
      file = unpackZigArtifact { inherit name; artifact = /. + path; };
    };
  in fetcher.${proto};
in linkFarm name [
  {
    name = "1220c198cdaf6cb73fca6603cc5039046ed10de2e9f884cae9224ff826731df1c68d";
    path = fetchZigArtifact {
      name = "ziggy";
      url = "git+https://github.com/kristoff-it/ziggy#ae30921d8c98970942d3711553aa66ff907482fe";
      hash = "sha256-dZemnsmM0383HnA7zhykyO/DnG0mx+PVjjr9NiIfu4I=";
    };
  }
  {
    name = "12209cde192558f8b3dc098ac2330fc2a14fdd211c5433afd33085af75caa9183147";
    path = fetchZigArtifact {
      name = "known-folders";
      url = "git+https://github.com/ziglibs/known-folders.git#0ad514dcfb7525e32ae349b9acc0a53976f3a9fa";
      hash = "sha256-X+XkFj56MkYxxN9LUisjnkfCxUfnbkzBWHy9pwg5M+g=";
    };
  }
  {
    name = "12204a4669fa6e8ebb1720e3581a24c1a7f538f2f4ee3ebc91a9e36285c89572d761";
    path = fetchZigArtifact {
      name = "zig-lsp-kit";
      url = "git+https://github.com/MFAshby/zig-lsp-kit.git#1c07e3e3305f8dd6355735173321c344fc152d3e";
      hash = "sha256-WBJ7hbc69W3mtzrMLwehcKccSbVe/8Dy9sX4IA4VbcY=";
    };
  }
  {
    name = "1220841471bd4891cbb199d27cc5e7e0fb0a5b7c5388a70bd24fa3eb7285755c396c";
    path = fetchZigArtifact {
      name = "yaml";
      url = "git+https://github.com/kubkon/zig-yaml.git#beddd5da24de91d430ca7028b00986f7745b13e9";
      hash = "sha256-CJms2LjwoYNlbhapFYzvOImuaMH/zikllYeQ2/VlHi0=";
    };
  }
]