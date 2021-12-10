# Praxis Pure Nix Test Suite: Module System & Priority Merging

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;

in
runner.runSuite "modules" [
  (runner.testCase "default_option_value" (_:
    let
      res = lib.evalModules {
        modules = [
          {
            options.server.port = lib.mkOption {
              type = lib.types.port;
              default = 8080;
            };
          }
        ];
      };
    in
    res.config.server.port == 8080
  ))

  (runner.testCase "override_default_with_explicit_value" (_:
    let
      res = lib.evalModules {
        modules = [
          {
            options.server.port = lib.mkOption {
              type = lib.types.port;
              default = 8080;
            };
            config.server.port = 9090;
          }
        ];
      };
    in
    res.config.server.port == 9090
  ))

  (runner.testCase "mkForce_overrides_standard_definition" (_:
    let
      res = lib.evalModules {
        modules = [
          {
            options.server.host = lib.mkOption {
              type = lib.types.str;
              default = "localhost";
            };
            config.server.host = "production.internal";
          }
          {
            config.server.host = lib.mkForce "forced.internal";
          }
        ];
      };
    in
    res.config.server.host == "forced.internal"
  ))

  (runner.testCase "mkDefault_yields_to_standard_definition" (_:
    let
      res = lib.evalModules {
        modules = [
          {
            options.service.timeout = lib.mkOption {
              type = lib.types.int;
            };
            config.service.timeout = lib.mkDefault 30;
          }
          {
            config.service.timeout = 60;
          }
        ];
      };
    in
    res.config.service.timeout == 60
  ))

  (runner.testCase "functional_module_context_injection" (_:
    let
      res = lib.evalModules {
        modules = [
          {
            options.cluster.name = lib.mkOption { type = lib.types.str; default = "praxis"; };
            options.cluster.fqdn = lib.mkOption { type = lib.types.str; };
          }
          ({ config, ... }: {
            config.cluster.fqdn = "${config.cluster.name}.internal.net";
          })
        ];
      };
    in
    res.config.cluster.fqdn == "praxis.internal.net"
  ))
]
