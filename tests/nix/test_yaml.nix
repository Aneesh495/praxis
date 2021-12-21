# Praxis Pure Nix Test Suite: YAML 1.2 Serialization

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  yaml = lib.yaml;

in
runner.runSuite "yaml" [
  (runner.testCase "yaml_mapping_and_scalars" (_:
    let
      val = {
        name = "praxis";
        replicas = 3;
        active = true;
      };
      res = yaml.toYAML val;
    in
    builtins.match ".*active: true.*" res != null &&
    builtins.match ".*name: praxis.*" res != null &&
    builtins.match ".*replicas: 3.*" res != null
  ))

  (runner.testCase "yaml_nested_lists" (_:
    let
      val = {
        items = [ "alpha" "beta" ];
      };
      res = yaml.toYAML val;
    in
    builtins.match ".*- alpha.*" res != null &&
    builtins.match ".*- beta.*" res != null
  ))
]
