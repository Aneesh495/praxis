# Praxis Pure Nix Test Suite: Tarjan's Strongly Connected Components & Cycles

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  tarjan = lib.tarjan;

in
runner.runSuite "tarjan" [
  (runner.testCase "dag_has_no_cycles" (_:
    let
      dag = {
        "A" = [ "B" "C" ];
        "B" = [ "D" ];
        "C" = [ "D" ];
        "D" = [];
      };
      res = tarjan.detectCycles dag;
    in
    !res.hasCycle && res.cycles == []
  ))

  (runner.testCase "detect_simple_cycle" (_:
    let
      cyclicGraph = {
        "X" = [ "Y" ];
        "Y" = [ "Z" ];
        "Z" = [ "X" ];
        "W" = [];
      };
      res = tarjan.detectCycles cyclicGraph;
    in
    res.hasCycle && builtins.length res.cycles == 1
  ))

  (runner.testCase "detect_self_loop" (_:
    let
      selfLoopGraph = {
        "A" = [ "A" ];
      };
      res = tarjan.detectCycles selfLoopGraph;
    in
    res.hasCycle
  ))

  (runner.testCase "partition_multiple_sccs" (_:
    let
      graph = {
        "1" = [ "2" ];
        "2" = [ "1" ]; # SCC 1: { 1 2 }
        "3" = [ "4" ];
        "4" = [ "3" ]; # SCC 2: { 3 4 }
        "5" = [];      # SCC 3: { 5 }
      };
      components = tarjan.scc graph;
    in
    builtins.length components == 3
  ))
]
