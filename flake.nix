{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      systems,
      ...
    }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            # Provides a system-specific, configured Nixpkgs
            pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            pkgs-unstable = import inputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs, pkgs-unstable }:
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules =
              let
                beamPkgs = pkgs-unstable.beam.packagesWith pkgs-unstable.beam.interpreters.erlang_28;
                elixir = beamPkgs.elixir_1_19;
                elixir-ls = beamPkgs.elixir-ls;
              in
              [
                {
                  packages =
                    with pkgs;
                    [
                      elixir-ls

                      git
                    ]
                    ++ lib.optionals stdenv.isLinux [
                      inotify-tools
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
                      exec = /* bash */ ''
                        mix do deps.get + ash.setup + assets.setup + assets.build
                        mix run --eval FinMan.Release.seed

                        iex --color --sname fin_man -S mix phx.server
                      '';
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
              ];
          };
        }
      );

      packages = forEachSupportedSystem (
        { pkgs, pkgs-unstable }:
        let
          beam_minimal = pkgs-unstable.beam_minimal;
          erlang_minimal = beam_minimal.interpreters.erlang_28;
          beamPkgsMinimal = beam_minimal.packagesWith erlang_minimal;
          elixir_minimal = beamPkgsMinimal.elixir_1_19;

          fin_man = pkgs.callPackage ./nix/package.nix {
            pname = "fin_man";
            version = "0.1.0";
            beamPackages = beamPkgsMinimal;
            erlang = erlang_minimal;
            elixir = elixir_minimal;
          };
        in
        {
          default = fin_man;
        }
      );

      nixosModules = {
        default = import ./nix/module.nix;
      };

      overlays.default = final: prev: {
        fin_man = self.packages.${prev.system}.default;
      };

      # To format all Nix files:
      # git ls-files -z '*.nix' | xargs -0 -r nix fmt
      # To check formatting:
      # git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check
      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt-rfc-style);
    };
}
