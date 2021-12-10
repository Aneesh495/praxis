# Praxis Pure Nix Test Suite: Structural Types & Contracts

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  types = lib.types;

in
runner.runSuite "types" [
  (runner.testCase "bool_check" (_:
    types.bool.check true && types.bool.check false && !types.bool.check 42
  ))

  (runner.testCase "int_check" (_:
    types.int.check 100 && types.int.check (-50) && !types.int.check "100"
  ))

  (runner.testCase "port_check" (_:
    types.port.check 80 && types.port.check 443 && types.port.check 65535 &&
    !types.port.check 0 && !types.port.check 65536 && !types.port.check "80"
  ))

  (runner.testCase "ipv4_check" (_:
    types.ipv4.check "192.168.1.1" && types.ipv4.check "10.0.0.1" &&
    types.ipv4.check "0.0.0.0" && types.ipv4.check "255.255.255.255" &&
    !types.ipv4.check "256.0.0.1" && !types.ipv4.check "10.0.0" && !types.ipv4.check "praxis"
  ))

  (runner.testCase "cidr_check" (_:
    types.cidr.check "10.0.0.0/16" && types.cidr.check "192.168.1.0/24" &&
    types.cidr.check "0.0.0.0/0" && !types.cidr.check "10.0.0.0/33" && !types.cidr.check "invalid"
  ))

  (runner.testCase "duration_check" (_:
    types.duration.check "30s" && types.duration.check "5m" &&
    types.duration.check "2h" && types.duration.check "1d" &&
    !types.duration.check "30x" && !types.duration.check "invalid"
  ))

  (runner.testCase "listOf_merge" (_:
    let
      listType = types.listOf types.int;
      defs = [
        { file = "a"; value = [ 1 2 ]; }
        { file = "b"; value = [ 3 4 ]; }
      ];
      merged = listType.merge [] defs;
    in
    merged == [ 1 2 3 4 ]
  ))

  (runner.testCase "enum_check" (_:
    let
      statusEnum = types.enum [ "RUNNING" "STOPPED" "FAILED" ];
    in
    statusEnum.check "RUNNING" && !statusEnum.check "UNKNOWN"
  ))
]
