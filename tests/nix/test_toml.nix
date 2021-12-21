# Praxis Pure Nix Test Suite: TOML v1.0 Serialization

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  toml = lib.toml;

in
runner.runSuite "toml" [
  (runner.testCase "toml_scalars_and_tables" (_:
    let
      val = {
        title = "Praxis Config";
        version = 1;
        server = {
          host = "127.0.0.1";
          port = 8080;
        };
      };
      res = toml.toTOML val;
    in
    builtins.match ".*title = \"Praxis Config\".*" res != null &&
    builtins.match ".*\\[server\\].*" res != null &&
    builtins.match ".*port = 8080.*" res != null
  ))
]
