# Praxis Pure Nix Test Suite: Disjoint-Set Union (Union-Find)

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  dsu = lib.disjointSet;

in
runner.runSuite "disjoint_set" [
  (runner.testCase "init_components" (_:
    let
      s = dsu.init [ "A" "B" "C" ];
    in
    s.numComponents == 3
  ))

  (runner.testCase "union_and_connected" (_:
    let
      s0 = dsu.init [ "node1" "node2" "node3" "node4" ];
      s1 = dsu.union "node1" "node2" s0;
      s2 = dsu.union "node3" "node4" s1;

      c12 = dsu.connected "node1" "node2" s2;
      c34 = dsu.connected "node3" "node4" s2;
      c13 = dsu.connected "node1" "node3" s2;
    in
    c12.connected && c34.connected && !c13.connected && s2.numComponents == 2
  ))

  (runner.testCase "component_equivalence_classes" (_:
    let
      s0 = dsu.init [ "1" "2" "3" "4" ];
      s1 = dsu.union "1" "2" s0;
      s2 = dsu.union "2" "3" s1;
      groups = dsu.components [ "1" "2" "3" "4" ] s2;
      groupList = builtins.attrValues groups;
    in
    builtins.length groupList == 2 # Group { 1 2 3 } and Group { 4 }
  ))
]
