{
  pkgs,
  lib,
  beamPackages,
  overrides ? (x: y: { }),
  overrideFenixOverlay ? null,
}:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  workarounds = {
    portCompiler = _unusedArgs: old: {
      buildPlugins = [ pkgs.beamPackages.pc ];
    };

    rustlerPrecompiled =
      {
        toolchain ? null,
        ...
      }:
      old:
      let
        extendedPkgs = pkgs.extend fenixOverlay;
        fenixOverlay =
          if overrideFenixOverlay == null then
            import "${
              fetchTarball {
                url = "https://github.com/nix-community/fenix/archive/056c9393c821a4df356df6ce7f14c722dc8717ec.tar.gz";
                sha256 = "sha256:1cdfh6nj81gjmn689snigidyq7w98gd8hkl5rvhly6xj7vyppmnd";
              }
            }/overlay.nix"
          else
            overrideFenixOverlay;
        nativeDir = "${old.src}/native/${with builtins; head (attrNames (readDir "${old.src}/native"))}";
        fenix =
          if toolchain == null then
            extendedPkgs.fenix.stable
          else
            extendedPkgs.fenix.fromToolchainName toolchain;
        native =
          (extendedPkgs.makeRustPlatform {
            inherit (fenix) cargo rustc;
          }).buildRustPackage
            {
              pname = "${old.packageName}-native";
              version = old.version;
              src = nativeDir;
              cargoLock = {
                lockFile = "${nativeDir}/Cargo.lock";
              };
              nativeBuildInputs = [
                extendedPkgs.cmake
              ];
              doCheck = false;
            };

      in
      {
        nativeBuildInputs = [ extendedPkgs.cargo ];

        env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
        env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

        preConfigure = ''
          mkdir -p priv/native
          for lib in ${native}/lib/*
          do
            ln -s "$lib" "priv/native/$(basename "$lib")"
          done
        '';

        buildPhase = ''
          suggestion() {
            echo "***********************************************"
            echo "                 deps_nix                      "
            echo
            echo " Rust dependency build failed.                 "
            echo
            echo " If you saw network errors, you might need     "
            echo " to disable compilation on the appropriate     "
            echo " RustlerPrecompiled module in your             "
            echo " application config.                           "
            echo
            echo " We think you need this:                       "
            echo
            echo -n " "
            grep -Rl 'use RustlerPrecompiled' lib \
              | xargs grep 'defmodule' \
              | sed 's/defmodule \(.*\) do/config :${old.packageName}, \1, skip_compilation?: true/'
            echo "***********************************************"
            exit 1
          }
          trap suggestion ERR
          ${old.buildPhase}
        '';
      };

    elixirMake = _unusedArgs: old: {
      preConfigure = ''
        export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/elixir_make_cache"
      '';
    };

    lazyHtml = _unusedArgs: old: {
      preConfigure = ''
        export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/elixir_make_cache"
      '';

      postPatch = ''
        substituteInPlace mix.exs           --replace-fail "Fine.include_dir()" '"${packages.fine}/src/c_include"'           --replace-fail '@lexbor_git_sha "244b84956a6dc7eec293781d051354f351274c46"' '@lexbor_git_sha ""'
      '';

      preBuild = ''
        install -Dm644           -t _build/c/third_party/lexbor/$LEXBOR_GIT_SHA/build           ${pkgs.lexbor}/lib/liblexbor_static.a
      '';
    };
  };

  defaultOverrides = (
    final: prev:

    let
      apps = {
        crc32cer = [
          {
            name = "portCompiler";
          }
        ];
        explorer = [
          {
            name = "rustlerPrecompiled";
            toolchain = {
              name = "nightly-2024-11-01";
              sha256 = "sha256-wq7bZ1/IlmmLkSa3GUJgK17dTWcKyf5A+ndS9yRwB88=";
            };
          }
        ];
        snappyer = [
          {
            name = "portCompiler";
          }
        ];
      };

      applyOverrides =
        appName: drv:
        let
          allOverridesForApp = builtins.foldl' (
            acc: workaround: acc // (workarounds.${workaround.name} workaround) drv
          ) { } apps.${appName};

        in
        if builtins.hasAttr appName apps then drv.override allOverridesForApp else drv;

    in
    builtins.mapAttrs applyOverrides prev
  );

  self = packages // (defaultOverrides self packages) // (overrides self packages);

  packages =
    with beamPackages;
    with self;
    {

      ash =
        let
          version = "3.8.0";
          drv = buildMix {
            inherit version;
            name = "ash";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ash";
              sha256 = "5ff1876a560b82bc91510f4d12dfacf0d024eeedb9cbe06e2b52fea2e9ba104c";
            };

            beamDeps = [
              crux
              decimal
              ecto
              ets
              jason
              plug
              reactor
              spark
              splode
              stream_data
              telemetry
            ];
          };
        in
        drv;

      ash_admin =
        let
          version = "0.13.23";
          drv = buildMix {
            inherit version;
            name = "ash_admin";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ash_admin";
              sha256 = "4d06e002313591e354ab25b4c82090261783fd8b50c773baea9f8a8ad370b834";
            };

            beamDeps = [
              ash
              ash_phoenix
              gettext
              jason
              phoenix
              phoenix_html
              phoenix_live_view
              phoenix_view
            ];
          };
        in
        drv;

      ash_double_entry =
        let
          version = "1.0.15";
          drv = buildMix {
            inherit version;
            name = "ash_double_entry";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ash_double_entry";
              sha256 = "7435bc7b37acd57d4448c9bf8751cf023c164407366c8646272832c4d6f96593";
            };

            beamDeps = [
              ash
              ash_money
              ex_money_sql
            ];
          };
        in
        drv;

      ash_money =
        let
          version = "0.2.5";
          drv = buildMix {
            inherit version;
            name = "ash_money";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ash_money";
              sha256 = "7182c64e1f2e7f84a53ef87f3d884ffb95be3de0725666a0d05ccbeab3fa6e18";
            };

            beamDeps = [
              ash
              ash_postgres
              ex_money
              ex_money_sql
            ];
          };
        in
        drv;

      ash_phoenix =
        let
          version = "2.3.18";
          drv = buildMix {
            inherit version;
            name = "ash_phoenix";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ash_phoenix";
              sha256 = "7ec28f9216221e83b90d9c3605e9d1cdd228984e09a1a86c9b9d393cebf25222";
            };

            beamDeps = [
              ash
              phoenix
              phoenix_html
              phoenix_live_view
              spark
            ];
          };
        in
        drv;

      ash_postgres =
        let
          version = "2.6.25";
          drv = buildMix {
            inherit version;
            name = "ash_postgres";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ash_postgres";
              sha256 = "dadf95dfb33d2807cfd393b57315e703a9c938a8fffbdeb2a0f59f28f1909eca";
            };

            beamDeps = [
              ash
              ash_sql
              ecto
              ecto_sql
              jason
              postgrex
              spark
            ];
          };
        in
        drv;

      ash_sql =
        let
          version = "0.3.11";
          drv = buildMix {
            inherit version;
            name = "ash_sql";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ash_sql";
              sha256 = "2fdae90f06752634406bd1be44bb2b33b1bf811f963e63df614e805c5164d209";
            };

            beamDeps = [
              ash
              ecto
              ecto_sql
            ];
          };
        in
        drv;

      bandit =
        let
          version = "1.8.0";
          drv = buildMix {
            inherit version;
            name = "bandit";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "bandit";
              sha256 = "8458ff4eed20ff2a2ea69d4854883a077c33ea42b51f6811b044ceee0fa15422";
            };

            beamDeps = [
              hpax
              plug
              telemetry
              thousand_island
              websock
            ];
          };
        in
        drv;

      cldr_utils =
        let
          version = "2.29.1";
          drv = buildMix {
            inherit version;
            name = "cldr_utils";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "cldr_utils";
              sha256 = "3844a0a0ed7f42e6590ddd8bd37eb4b1556b112898f67dea3ba068c29aabd6c2";
            };

            beamDeps = [
              decimal
            ];
          };
        in
        drv;

      crux =
        let
          version = "0.1.2";
          drv = buildMix {
            inherit version;
            name = "crux";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "crux";
              sha256 = "563ea3748ebfba9cc078e6d198a1d6a06015a8fae503f0b721363139f0ddb350";
            };

            beamDeps = [
              stream_data
            ];
          };
        in
        drv;

      db_connection =
        let
          version = "2.8.1";
          drv = buildMix {
            inherit version;
            name = "db_connection";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "db_connection";
              sha256 = "a61a3d489b239d76f326e03b98794fb8e45168396c925ef25feb405ed09da8fd";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      decimal =
        let
          version = "2.3.0";
          drv = buildMix {
            inherit version;
            name = "decimal";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "decimal";
              sha256 = "a4d66355cb29cb47c3cf30e71329e58361cfcb37c34235ef3bf1d7bf3773aeac";
            };
          };
        in
        drv;

      digital_token =
        let
          version = "1.0.0";
          drv = buildMix {
            inherit version;
            name = "digital_token";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "digital_token";
              sha256 = "8ed6f5a8c2fa7b07147b9963db506a1b4c7475d9afca6492136535b064c9e9e6";
            };

            beamDeps = [
              cldr_utils
              jason
            ];
          };
        in
        drv;

      dns_cluster =
        let
          version = "0.2.0";
          drv = buildMix {
            inherit version;
            name = "dns_cluster";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "dns_cluster";
              sha256 = "ba6f1893411c69c01b9e8e8f772062535a4cf70f3f35bcc964a324078d8c8240";
            };
          };
        in
        drv;

      ecto =
        let
          version = "3.13.5";
          drv = buildMix {
            inherit version;
            name = "ecto";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ecto";
              sha256 = "df9efebf70cf94142739ba357499661ef5dbb559ef902b68ea1f3c1fabce36de";
            };

            beamDeps = [
              decimal
              jason
              telemetry
            ];
          };
        in
        drv;

      ecto_sql =
        let
          version = "3.13.2";
          drv = buildMix {
            inherit version;
            name = "ecto_sql";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ecto_sql";
              sha256 = "539274ab0ecf1a0078a6a72ef3465629e4d6018a3028095dc90f60a19c371717";
            };

            beamDeps = [
              db_connection
              ecto
              postgrex
              telemetry
            ];
          };
        in
        drv;

      esbuild =
        let
          version = "0.10.0";
          drv = buildMix {
            inherit version;
            name = "esbuild";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "esbuild";
              sha256 = "468489cda427b974a7cc9f03ace55368a83e1a7be12fba7e30969af78e5f8c70";
            };

            beamDeps = [
              jason
            ];
          };
        in
        drv;

      ets =
        let
          version = "0.9.0";
          drv = buildMix {
            inherit version;
            name = "ets";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ets";
              sha256 = "2861fdfb04bcaeff370f1a5904eec864f0a56dcfebe5921ea9aadf2a481c822b";
            };
          };
        in
        drv;

      ex_cldr =
        let
          version = "2.44.0";
          drv = buildMix {
            inherit version;
            name = "ex_cldr";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr";
              sha256 = "58260baac6308156595cd0a2b81c09ac8e05dd64fd2a19c8b0ef309fdcdcd7ee";
            };

            beamDeps = [
              cldr_utils
              decimal
              gettext
              jason
              nimble_parsec
            ];
          };
        in
        drv;

      ex_cldr_currencies =
        let
          version = "2.16.5";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_currencies";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_currencies";
              sha256 = "4397179028f0a7389de278afd0239771f39ba8d1984ce072bc9b715fa28f30d3";
            };

            beamDeps = [
              ex_cldr
              jason
            ];
          };
        in
        drv;

      ex_cldr_numbers =
        let
          version = "2.36.0";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_numbers";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_numbers";
              sha256 = "17640b8daf2580a0a11317a720a26079e774d4c36f939d82f4e9f7075269897d";
            };

            beamDeps = [
              decimal
              digital_token
              ex_cldr
              ex_cldr_currencies
              jason
            ];
          };
        in
        drv;

      ex_money =
        let
          version = "5.23.0";
          drv = buildMix {
            inherit version;
            name = "ex_money";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ex_money";
              sha256 = "397f77b02a7939fa0e8286819f18406540be201f7f3d6c04070654995dac32d2";
            };

            beamDeps = [
              decimal
              ex_cldr_numbers
              jason
              nimble_parsec
              phoenix_html
            ];
          };
        in
        drv;

      ex_money_sql =
        let
          version = "1.11.1";
          drv = buildMix {
            inherit version;
            name = "ex_money_sql";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ex_money_sql";
              sha256 = "ad1dc3c23b9269cd62b37991156cafa1dd3cca510c612a4b7fc7be614c67385f";
            };

            beamDeps = [
              ecto
              ecto_sql
              ex_money
              jason
              postgrex
            ];
          };
        in
        drv;

      expo =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "expo";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "expo";
              sha256 = "5fb308b9cb359ae200b7e23d37c76978673aa1b06e2b3075d814ce12c5811640";
            };
          };
        in
        drv;

      finch =
        let
          version = "0.20.0";
          drv = buildMix {
            inherit version;
            name = "finch";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "finch";
              sha256 = "2658131a74d051aabfcba936093c903b8e89da9a1b63e430bee62045fa9b2ee2";
            };

            beamDeps = [
              mime
              mint
              nimble_options
              nimble_pool
              telemetry
            ];
          };
        in
        drv;

      gettext =
        let
          version = "0.26.2";
          drv = buildMix {
            inherit version;
            name = "gettext";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "gettext";
              sha256 = "aa978504bcf76511efdc22d580ba08e2279caab1066b76bb9aa81c4a1e0a32a5";
            };

            beamDeps = [
              expo
            ];
          };
        in
        drv;

      heroicons = pkgs.fetchFromGitHub {
        owner = "tailwindlabs";
        repo = "heroicons";
        rev = "0435d4ca364a608cc75e2f8683d374e55abbae26";
        hash = "sha256-Jcxr1fSbmXO9bZKeg39Z/zVN0YJp17TX3LH5Us4lsZU=";
      };

      hpax =
        let
          version = "1.0.3";
          drv = buildMix {
            inherit version;
            name = "hpax";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "hpax";
              sha256 = "8eab6e1cfa8d5918c2ce4ba43588e894af35dbd8e91e6e55c817bca5847df34a";
            };
          };
        in
        drv;

      idna =
        let
          version = "6.1.1";
          drv = buildRebar3 {
            inherit version;
            name = "idna";

            src = fetchHex {
              inherit version;
              pkg = "idna";
              sha256 = "92376eb7894412ed19ac475e4a86f7b413c1b9fbb5bd16dccd57934157944cea";
            };

            beamDeps = [
              unicode_util_compat
            ];
          };
        in
        drv;

      iterex =
        let
          version = "0.1.2";
          drv = buildMix {
            inherit version;
            name = "iterex";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "iterex";
              sha256 = "2e103b8bcc81757a9af121f6dc0df312c9a17220f302b1193ef720460d03029d";
            };
          };
        in
        drv;

      jason =
        let
          version = "1.4.4";
          drv = buildMix {
            inherit version;
            name = "jason";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "jason";
              sha256 = "c5eb0cab91f094599f94d55bc63409236a8ec69a21a67814529e8d5f6cc90b3b";
            };

            beamDeps = [
              decimal
            ];
          };
        in
        drv;

      libgraph =
        let
          version = "0.16.0";
          drv = buildMix {
            inherit version;
            name = "libgraph";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "libgraph";
              sha256 = "41ca92240e8a4138c30a7e06466acc709b0cbb795c643e9e17174a178982d6bf";
            };
          };
        in
        drv;

      mime =
        let
          version = "2.0.7";
          drv = buildMix {
            inherit version;
            name = "mime";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "mime";
              sha256 = "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd";
            };
          };
        in
        drv;

      mint =
        let
          version = "1.7.1";
          drv = buildMix {
            inherit version;
            name = "mint";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "mint";
              sha256 = "fceba0a4d0f24301ddee3024ae116df1c3f4bb7a563a731f45fdfeb9d39a231b";
            };

            beamDeps = [
              hpax
            ];
          };
        in
        drv;

      nimble_options =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "nimble_options";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_options";
              sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44";
            };
          };
        in
        drv;

      nimble_parsec =
        let
          version = "1.4.2";
          drv = buildMix {
            inherit version;
            name = "nimble_parsec";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_parsec";
              sha256 = "4b21398942dda052b403bbe1da991ccd03a053668d147d53fb8c4e0efe09c973";
            };
          };
        in
        drv;

      nimble_pool =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "nimble_pool";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_pool";
              sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a";
            };
          };
        in
        drv;

      phoenix =
        let
          version = "1.8.1";
          drv = buildMix {
            inherit version;
            name = "phoenix";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix";
              sha256 = "84d77d2b2e77c3c7e7527099bd01ef5c8560cd149c036d6b3a40745f11cd2fb2";
            };

            beamDeps = [
              bandit
              jason
              phoenix_pubsub
              phoenix_template
              phoenix_view
              plug
              plug_crypto
              telemetry
              websock_adapter
            ];
          };
        in
        drv;

      phoenix_ecto =
        let
          version = "4.7.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_ecto";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_ecto";
              sha256 = "1d75011e4254cb4ddf823e81823a9629559a1be93b4321a6a5f11a5306fbf4cc";
            };

            beamDeps = [
              ecto
              phoenix_html
              plug
              postgrex
            ];
          };
        in
        drv;

      phoenix_html =
        let
          version = "4.3.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_html";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_html";
              sha256 = "3eaa290a78bab0f075f791a46a981bbe769d94bc776869f4f3063a14f30497ad";
            };
          };
        in
        drv;

      phoenix_live_dashboard =
        let
          version = "0.8.7";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_dashboard";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_dashboard";
              sha256 = "3a8625cab39ec261d48a13b7468dc619c0ede099601b084e343968309bd4d7d7";
            };

            beamDeps = [
              ecto
              mime
              phoenix_live_view
              telemetry_metrics
            ];
          };
        in
        drv;

      phoenix_live_view =
        let
          version = "1.1.17";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_view";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_view";
              sha256 = "fa82307dd9305657a8236d6b48e60ef2e8d9f742ee7ed832de4b8bcb7e0e5ed2";
            };

            beamDeps = [
              jason
              phoenix
              phoenix_html
              phoenix_template
              phoenix_view
              plug
              telemetry
            ];
          };
        in
        drv;

      phoenix_pubsub =
        let
          version = "2.2.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_pubsub";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_pubsub";
              sha256 = "adc313a5bf7136039f63cfd9668fde73bba0765e0614cba80c06ac9460ff3e96";
            };
          };
        in
        drv;

      phoenix_template =
        let
          version = "1.0.4";
          drv = buildMix {
            inherit version;
            name = "phoenix_template";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_template";
              sha256 = "2c0c81f0e5c6753faf5cca2f229c9709919aba34fab866d3bc05060c9c444206";
            };

            beamDeps = [
              phoenix_html
            ];
          };
        in
        drv;

      phoenix_view =
        let
          version = "2.0.4";
          drv = buildMix {
            inherit version;
            name = "phoenix_view";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_view";
              sha256 = "4e992022ce14f31fe57335db27a28154afcc94e9983266835bb3040243eb620b";
            };

            beamDeps = [
              phoenix_html
              phoenix_template
            ];
          };
        in
        drv;

      plug =
        let
          version = "1.18.1";
          drv = buildMix {
            inherit version;
            name = "plug";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "plug";
              sha256 = "57a57db70df2b422b564437d2d33cf8d33cd16339c1edb190cd11b1a3a546cc2";
            };

            beamDeps = [
              mime
              plug_crypto
              telemetry
            ];
          };
        in
        drv;

      plug_crypto =
        let
          version = "2.1.1";
          drv = buildMix {
            inherit version;
            name = "plug_crypto";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "plug_crypto";
              sha256 = "6470bce6ffe41c8bd497612ffde1a7e4af67f36a15eea5f921af71cf3e11247c";
            };
          };
        in
        drv;

      postgrex =
        let
          version = "0.21.1";
          drv = buildMix {
            inherit version;
            name = "postgrex";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "postgrex";
              sha256 = "27d8d21c103c3cc68851b533ff99eef353e6a0ff98dc444ea751de43eb48bdac";
            };

            beamDeps = [
              db_connection
              decimal
              jason
            ];
          };
        in
        drv;

      reactor =
        let
          version = "0.17.0";
          drv = buildMix {
            inherit version;
            name = "reactor";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "reactor";
              sha256 = "3c3bf71693adbad9117b11ec83cfed7d5851b916ade508ed9718de7ae165bf25";
            };

            beamDeps = [
              iterex
              jason
              libgraph
              spark
              splode
              telemetry
              yaml_elixir
              ymlr
            ];
          };
        in
        drv;

      req =
        let
          version = "0.5.15";
          drv = buildMix {
            inherit version;
            name = "req";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "req";
              sha256 = "a6513a35fad65467893ced9785457e91693352c70b58bbc045b47e5eb2ef0c53";
            };

            beamDeps = [
              finch
              jason
              mime
              plug
            ];
          };
        in
        drv;

      spark =
        let
          version = "2.3.13";
          drv = buildMix {
            inherit version;
            name = "spark";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "spark";
              sha256 = "d06de23b5e8961d98c9c81d798dbafb9ac64694da19b0e9ca4ba4a8a54b75e31";
            };

            beamDeps = [
              jason
            ];
          };
        in
        drv;

      splode =
        let
          version = "0.2.9";
          drv = buildMix {
            inherit version;
            name = "splode";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "splode";
              sha256 = "8002b00c6e24f8bd1bcced3fbaa5c33346048047bb7e13d2f3ad428babbd95c3";
            };
          };
        in
        drv;

      stream_data =
        let
          version = "1.2.0";
          drv = buildMix {
            inherit version;
            name = "stream_data";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "stream_data";
              sha256 = "eb5c546ee3466920314643edf68943a5b14b32d1da9fe01698dc92b73f89a9ed";
            };
          };
        in
        drv;

      swoosh =
        let
          version = "1.19.8";
          drv = buildMix {
            inherit version;
            name = "swoosh";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "swoosh";
              sha256 = "d7503c2daf0f9899afd8eba9923eeddef4b62e70816e1d3b6766e4d6c60e94ad";
            };

            beamDeps = [
              bandit
              finch
              idna
              jason
              mime
              plug
              req
              telemetry
            ];
          };
        in
        drv;

      tailwind =
        let
          version = "0.4.1";
          drv = buildMix {
            inherit version;
            name = "tailwind";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "tailwind";
              sha256 = "6249d4f9819052911120dbdbe9e532e6bd64ea23476056adb7f730aa25c220d1";
            };
          };
        in
        drv;

      telemetry =
        let
          version = "1.3.0";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry";

            src = fetchHex {
              inherit version;
              pkg = "telemetry";
              sha256 = "7015fc8919dbe63764f4b4b87a95b7c0996bd539e0d499be6ec9d7f3875b79e6";
            };
          };
        in
        drv;

      telemetry_metrics =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "telemetry_metrics";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "telemetry_metrics";
              sha256 = "e7b79e8ddfde70adb6db8a6623d1778ec66401f366e9a8f5dd0955c56bc8ce67";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      telemetry_poller =
        let
          version = "1.3.0";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry_poller";

            src = fetchHex {
              inherit version;
              pkg = "telemetry_poller";
              sha256 = "51f18bed7128544a50f75897db9974436ea9bfba560420b646af27a9a9b35211";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      thousand_island =
        let
          version = "1.4.2";
          drv = buildMix {
            inherit version;
            name = "thousand_island";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "thousand_island";
              sha256 = "1c7637f16558fc1c35746d5ee0e83b18b8e59e18d28affd1f2fa1645f8bc7473";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      unicode_util_compat =
        let
          version = "0.7.1";
          drv = buildRebar3 {
            inherit version;
            name = "unicode_util_compat";

            src = fetchHex {
              inherit version;
              pkg = "unicode_util_compat";
              sha256 = "b3a917854ce3ae233619744ad1e0102e05673136776fb2fa76234f3e03b23642";
            };
          };
        in
        drv;

      websock =
        let
          version = "0.5.3";
          drv = buildMix {
            inherit version;
            name = "websock";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "websock";
              sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453";
            };
          };
        in
        drv;

      websock_adapter =
        let
          version = "0.5.9";
          drv = buildMix {
            inherit version;
            name = "websock_adapter";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "websock_adapter";
              sha256 = "5534d5c9adad3c18a0f58a9371220d75a803bf0b9a3d87e6fe072faaeed76a08";
            };

            beamDeps = [
              bandit
              plug
              websock
            ];
          };
        in
        drv;

      yamerl =
        let
          version = "0.10.0";
          drv = buildRebar3 {
            inherit version;
            name = "yamerl";

            src = fetchHex {
              inherit version;
              pkg = "yamerl";
              sha256 = "346adb2963f1051dc837a2364e4acf6eb7d80097c0f53cbdc3046ec8ec4b4e6e";
            };
          };
        in
        drv;

      yaml_elixir =
        let
          version = "2.12.0";
          drv = buildMix {
            inherit version;
            name = "yaml_elixir";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "yaml_elixir";
              sha256 = "ca6bacae7bac917a7155dca0ab6149088aa7bc800c94d0fe18c5238f53b313c6";
            };

            beamDeps = [
              yamerl
            ];
          };
        in
        drv;

      ymlr =
        let
          version = "5.1.4";
          drv = buildMix {
            inherit version;
            name = "ymlr";
            appConfigPath = ../config;

            src = fetchHex {
              inherit version;
              pkg = "ymlr";
              sha256 = "75f16cf0709fbd911b30311a0359a7aa4b5476346c01882addefd5f2b1cfaa51";
            };
          };
        in
        drv;

    };
in
self
