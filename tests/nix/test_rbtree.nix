# Praxis Pure Nix Test Suite: Red-Black Balanced Binary Search Tree

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  rbtree = lib.rbtree;

in
runner.runSuite "rbtree" [
  (runner.testCase "empty_tree" (_:
    rbtree.isEmpty rbtree.empty && rbtree.size rbtree.empty == 0
  ))

  (runner.testCase "insert_and_lookup" (_:
    let
      t0 = rbtree.empty;
      t1 = rbtree.insert 10 "val10" t0;
      t2 = rbtree.insert 20 "val20" t1;
      t3 = rbtree.insert 5 "val5" t2;
    in
    (rbtree.lookup 10 t3).found &&
    (rbtree.lookup 10 t3).value == "val10" &&
    (rbtree.lookup 20 t3).value == "val20" &&
    (rbtree.lookup 5 t3).value == "val5" &&
    !(rbtree.lookup 99 t3).found
  ))

  (runner.testCase "red_black_balancing_invariants" (_:
    # Insert elements in descending order (triggers Left-Left rebalancing)
    let
      t = builtins.foldl' (acc: i: rbtree.insert i ("v" + toString i) acc) rbtree.empty [ 10 9 8 7 6 5 4 3 2 1 ];
    in
    rbtree.size t == 10 &&
    rbtree.isBalanced t
  ))

  (runner.testCase "to_sorted_list" (_:
    let
      elements = [
        { key = 50; value = "fifty"; }
        { key = 20; value = "twenty"; }
        { key = 70; value = "seventy"; }
        { key = 10; value = "ten"; }
      ];
      t = rbtree.fromList elements;
      sorted = rbtree.toList t;
      keys = builtins.map (item: item.key) sorted;
    in
    keys == [ 10 20 50 70 ]
  ))

  (runner.testCase "min_and_max_nodes" (_:
    let
      t = rbtree.fromList [
        { key = 40; value = "a"; }
        { key = 15; value = "b"; }
        { key = 85; value = "c"; }
      ];
    in
    (rbtree.minNode t).key == 15 &&
    (rbtree.maxNode t).key == 85
  ))
]
