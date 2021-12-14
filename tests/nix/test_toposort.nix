# Praxis Pure Nix Test Suite: Kahn's Topological Sort & Level Scheduler

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  toposort = lib.toposort;

in
runner.runSuite "toposort" [
  (runner.testCase "linear_pipeline_sort" (_:
    let
      # compile -> test -> package -> deploy
      pipeline = {
        "compile" = [];
        "test" = [ "compile" ];
        "package" = [ "test" ];
        "deploy" = [ "package" ];
      };
      res = toposort.sort pipeline;
    in
    res.success && res.order == [ "compile" "test" "package" "deploy" ]
  ))

  (runner.testCase "parallel_level_scheduling" (_:
    let
      # A and B can run in parallel (Level 0)
      # C depends on A and B (Level 1)
      graph = {
        "A" = [];
        "B" = [];
        "C" = [ "A" "B" ];
      };
      res = toposort.sort graph;
      lvl0 = builtins.elemAt res.levels 0;
      lvl1 = builtins.elemAt res.levels 1;
    in
    res.success &&
    builtins.length res.levels == 2 &&
    builtins.elem "A" lvl0 && builtins.elem "B" lvl0 &&
    lvl1 == [ "C" ]
  ))

  (runner.testCase "cycle_detection_in_toposort" (_:
    let
      cyclic = {
        "service-1" = [ "service-2" ];
        "service-2" = [ "service-1" ];
      };
      res = toposort.sort cyclic;
    in
    !res.success && res.cycle != []
  ))
]
