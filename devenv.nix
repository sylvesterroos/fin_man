{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };

  beamPkgs = pkgs-unstable.beam.packagesWith pkgs-unstable.beam.interpreters.erlang_27;
  elixir = beamPkgs.elixir_1_18;
in
{
  packages = with pkgs; [ git ];

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
