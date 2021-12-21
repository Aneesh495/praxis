# Praxis Pure Nix Test Suite: Deterministic JSON Serialization

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  json = lib.json;

in
runner.runSuite "json" [
  (runner.testCase "compact_json_sorted_keys" (_:
    let
      val = { z = 1; a = 2; m = 3; };
      res = json.toCompactJSON val;
    in
    res == "{\"a\":2,\"m\":3,\"z\":1}"
  ))

  (runner.testCase "nested_structures" (_:
    let
      val = {
        name = "praxis";
        enabled = true;
        ports = [ 80 443 ];
      };
      res = json.toCompactJSON val;
    in
    res == "{\"enabled\":true,\"name\":\"praxis\",\"ports\":[80,443]}"
  ))
]
