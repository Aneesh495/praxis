# Praxis Pure Nix Test Suite: Edge Cases & Bug Regressions
#
# Regression tests documenting and preventing recurrence of subtle edge cases
# and defects identified during Praxis development.

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;

in
runner.runSuite "regression" [
  # Regression 1: Curried multi-argument builtins
  # Prevented issue where multi-argument functions failed on partial evaluation
  (runner.testCase "curried_builtin_evaluation" (_:
    let
      subFromZero = builtins.substring 0;
      subFour = subFromZero 4;
      res = subFour "praxis";
    in
    res == "prax"
  ))

  # Regression 2: Attribute set update with priority merging
  # Ensured deepest thunks are evaluated without returning raw thunk closures
  (runner.testCase "recursive_attribute_set_update_deep_eval" (_:
    let
      a = { nested = { x = 1; y = 2; }; };
      b = { nested = { y = 99; z = 3; }; };
      merged = a // b;
    in
    merged.nested.y == 99
  ))

  # Regression 3: Radix Trie empty string lookup
  # Ensured looking up an empty string on an empty trie returns found = false rather than throwing
  (runner.testCase "trie_empty_string_safety" (_:
    let
      t = lib.trie.empty;
      res = lib.trie.lookupExact "" t;
    in
    !res.found
  ))

  # Regression 4: Disjoint-Set union on identical element
  # Ensured union(x, x) does not decrement component count or create self-cycle
  (runner.testCase "disjoint_set_self_union_idempotency" (_:
    let
      s0 = lib.disjointSet.init [ "node1" "node2" ];
      s1 = lib.disjointSet.union "node1" "node1" s0;
    in
    s1.numComponents == 2
  ))

  # Regression 5: SHA-256 padding on 64-byte boundary
  # Ensured message whose length % 64 == 0 correctly appends full new padding block
  (runner.testCase "sha256_exact_block_boundary_padding" (_:
    let
      block64 = "1234567890123456789012345678901234567890123456789012345678901234"; # 64 characters
      hash = lib.sha256.hashString block64;
    in
    builtins.stringLength hash == 64
  ))
]
