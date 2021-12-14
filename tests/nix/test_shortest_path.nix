# Praxis Pure Nix Test Suite: Dijkstra Shortest Path Routing Engine

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  sp = lib.shortestPath;

in
runner.runSuite "shortest_path" [
  (runner.testCase "dijkstra_minimal_latency_path" (_:
    let
      # Graph:
      # A --(10)--> B --(5)--> C (total 15)
      # A --(20)--> C           (total 20)
      graph = {
        "A" = [ { node = "B"; weight = 10; } { node = "C"; weight = 20; } ];
        "B" = [ { node = "C"; weight = 5; } ];
        "C" = [];
      };
      res = sp.dijkstra graph "A";
    in
    res.distances."A" == 0 &&
    res.distances."B" == 10 &&
    res.distances."C" == 15 && # Optimal path A -> B -> C (15) instead of direct (20)
    res.previous."C" == "B" &&
    res.routingTable."C" == "B" # Next-hop from A to reach C is B
  ))

  (runner.testCase "path_reconstruction" (_:
    let
      graph = {
        "gw1" = [ { node = "router1"; weight = 2; } ];
        "router1" = [ { node = "router2"; weight = 3; } ];
        "router2" = [ { node = "dest"; weight = 1; } ];
        "dest" = [];
      };
      res = sp.dijkstra graph "gw1";
      path = sp.reconstructPath res.previous "gw1" "dest";
    in
    path == [ "gw1" "router1" "router2" "dest" ]
  ))
]
