{
  lib,
  pkgs,
  config,
  ...
}:

with lib;
let
  cfg = config.services.fin_man;
in
{
  options.services.fin_man = {
    enable = mkEnableOption "fin_man";

    package = mkPackageOption pkgs "fin_man" { };

    database = {
      postgres = {
        setup = mkEnableOption "creating a postgresql instance" // {
          default = true;
        };
        dbname = mkOption {
          default = "fin_man";
          type = types.str;
          description = ''
            Name of the database to use.
          '';
        };
        socket = mkOption {
          default = "/run/postgresql";
          type = types.str;
          description = ''
            Path to the UNIX domain-socket to communicate with `postgres`.
          '';
        };
      };
    };

    server = {
      secretKeyBaseFile = mkOption {
        type = types.either types.path types.str;
        description = ''
          Path to the secret used by the `phoenix`-framework. Instructions
          how to generate one are documented in the
          [framework docs](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Secret.html#content).
        '';
      };
      listenAddress = mkOption {
        default = "127.0.0.1";
        type = types.str;
        description = ''
          The IP address on which the server is listening.
        '';
      };
      port = mkOption {
        default = 8000;
        type = types.port;
        description = ''
          Port where the service should be available.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.postgresql = mkIf cfg.database.postgres.setup {
      enable = true;

      ensureUsers = [
        {
          name = "fin_man";
          ensureDBOwnership = true;
          ensureClauses = {
            login = true;
            createrole = true;
          };
        }
      ];

      ensureDatabases = [ "fin_man" ];
    };

    environment.systemPackages = [ cfg.package ];

    systemd.services = {
      fin_man = {
        wantedBy = [ "multi-user.target" ];
        after = optionals cfg.database.postgres.setup [
          "postgresql.target"
        ];
        requires = optionals cfg.database.postgres.setup [
          "postgresql.target"
        ];

        environment = {
          # Configuration options
          PORT = toString cfg.server.port;
          LISTEN_IP = cfg.server.listenAddress;

          # Since fin_man does not use Erlang's distributed features, we just disable it
          RELEASE_DISTRIBUTION = "none";
          # Additional safeguard, in case `RELEASE_DISTRIBUTION=none` ever
          # stops disabling the start of EPMD.
          ERL_EPMD_ADDRESS = "127.0.0.1";

          RELEASE_TMP = "/var/lib/fin_man/tmp";
          # Home is needed to connect to the node with iex
          HOME = "/var/lib/fin_man";

          DATABASE_URL = "postgresql:///${cfg.database.postgres.dbname}?host=${cfg.database.postgres.socket}";
        };

        path = [ cfg.package ] ++ optional cfg.database.postgres.setup config.services.postgresql.package;
        script = ''
          # Elixir does not start up if `RELEASE_COOKIE` is not set,
          # even though we set `RELEASE_DISTRIBUTION=none` so the cookie should be unused.
          # Thus, make a random one, which should then be ignored.
          export RELEASE_COOKIE=$(dd if=/dev/urandom bs=20 count=1 2>/dev/null | base64 | tr -d '/+=' | head -c 20)
          export SECRET_KEY_BASE="$(< $CREDENTIALS_DIRECTORY/SECRET_KEY_BASE )"

          ${cfg.package}/bin/migrate

          ${cfg.package}/bin/server
        '';

        serviceConfig = {
          DynamicUser = true;
          PrivateTmp = true;
          WorkingDirectory = "/var/lib/fin_man";
          StateDirectory = "fin_man";
          LoadCredential = [
            "SECRET_KEY_BASE:${cfg.server.secretKeyBaseFile}"
          ];
        };
      };
    };
  };
}
