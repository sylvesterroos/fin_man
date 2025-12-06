{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  pname = "fin_man";
  version = "0.1.0";

  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };

  beamPkgs = pkgs-unstable.beam.packagesWith pkgs-unstable.beam.interpreters.erlang_28;
  elixir = beamPkgs.elixir_1_19;

  beam_minimal = pkgs-unstable.beam_minimal;
  erlang_minimal = beam_minimal.interpreters.erlang_28;
  beamPkgsMinimal = beam_minimal.packagesWith erlang_minimal;
  elixir_minimal = beamPkgsMinimal.elixir_1_19;

  release_minimal = pkgs-unstable.callPackage ./nix/package.nix {
    inherit pname version;
    beamPackages = beamPkgsMinimal;
    erlang = erlang_minimal;
    elixir = elixir_minimal;
  };
in
{
  outputs = {
    ${pname} = release_minimal;
  };

  packages = with pkgs; [
    git
  ];

  languages.nix = {
    enable = true;
    lsp.package = pkgs.nil;
  };
  languages.elixir = {
    enable = true;
    package = elixir;
  };

  processes = {
    fin_man = {
      exec = "iex --color --sname fin_man -S mix phx.server";
      process-compose = {
        is_tty = true;
        depends_on = {
          postgres = {
            condition = "process_healthy";
          };
        };
      };
    };
  };

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_18;
    port = 5432;
    listen_addresses = "localhost";
    initialDatabases = [ { name = "postgres"; } ];
    initialScript = ''
      CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
    '';
  };

  # See full reference at https://devenv.sh/reference/options/
}
