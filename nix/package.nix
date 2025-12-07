{
  beamPackages,
  callPackages,
  elixir,
  erlang,
  esbuild,
  lib,
  nix-gitignore,
  pname,
  tailwindcss_4,
  version,
}:
let
  src = nix-gitignore.gitignoreSource [
    "/nix"
  ] ../.;

  mixNixDeps = callPackages ./deps.nix { };
in
beamPackages.mixRelease {
  inherit
    elixir
    erlang
    mixNixDeps
    pname
    src
    version
    ;

  preBuild = # bash
    ''
      cat >> config/config.exs <<EOF
      config :tailwind, path: "${lib.getExe tailwindcss_4}"
      config :esbuild, path: "${lib.getExe esbuild}"
      EOF
    '';

  postBuild = # bash
    ''
      ln -sfv ${mixNixDeps.heroicons} deps/heroicons

      mix do deps.loadpaths --no-deps-check + assets.deploy
      mix do deps.loadpaths --no-deps-check + phx.digest priv/static
    '';

  stripDebug = true;
  removeCookie = true;

  meta.mainProgram = pname;
}
