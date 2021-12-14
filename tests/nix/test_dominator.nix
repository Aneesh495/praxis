# Praxis Pure Nix Test Suite: Lengauer-Tarjan Dominator Tree & Chokepoints

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  dominator = lib.dominator;

in
runner.runSuite "dominator" [
  (runner.testCase "linear_pipeline_dominators" (_:
    let
      # Entry -> Gateway -> Worker
      flow = {
        "entry" = [ "gateway" ];
        "gateway" = [ "worker" ];
        "worker" = [];
      };
      res = dominator.computeDominators flow "entry";
    in
    res.idom."gateway" == "entry" &&
    res.idom."worker" == "gateway" &&
    builtins.elem "gateway" res.chokepoints
  ))

  (runner.testCase "diamond_graph_reconvergence" (_:
    let
      # Entry -> Left -> Reconvergence
      # Entry -> Right -> Reconvergence
      flow = {
        "entry" = [ "left" "right" ];
        "left" = [ "sink" ];
        "right" = [ "sink" ];
        "sink" = [];
      };
      res = dominator.computeDominators flow "entry";
    in
    res.idom."sink" == "entry" &&
    !builtins.elem "left" res.dominators."sink" &&
    !builtins.elem "right" res.dominators."sink"
  ))
]
