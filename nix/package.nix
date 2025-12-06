{
  beamPackages,
  elixir,
  erlang,
  esbuild,
  fetchFromGitHub,
  lib,
  nix-gitignore,
  pname,
  tailwindcss_4,
  version,
}:
let
  src = nix-gitignore.gitignoreSource [ ] ../.;

  mixFodDeps = beamPackages.fetchMixDeps {
    inherit version src;
    pname = "${pname}-mix-deps";
    hash = "sha256-uiuNL1oBTnUJCHlhD2j5cjAvoAtjn04Qn3voPeex1PY=";
  };

  heroicons = fetchFromGitHub {
    owner = "tailwindlabs";
    repo = "heroicons";
    rev = "v2.2.0";
    hash = "sha256-Jcxr1fSbmXO9bZKeg39Z/zVN0YJp17TX3LH5Us4lsZU=";
  };
in
beamPackages.mixRelease {
  inherit
    src
    pname
    version
    erlang
    elixir
    mixFodDeps
    ;

  preBuild = # bash
    ''
      cp -r ${heroicons} deps/heroicons

      cat >> config/config.exs <<EOF
      config :tailwind, path: "${lib.getExe tailwindcss_4}"
      config :esbuild, path: "${lib.getExe esbuild}"
      EOF
    '';

  postBuild = # bash
    ''
      mix do deps.loadpaths --no-deps-check, assets.deploy
      mix do deps.loadpaths --no-deps-check, phx.digest priv/static
    '';

  stripDebug = true;
  removeCookie = false;

  meta.mainProgram = pname;
}
