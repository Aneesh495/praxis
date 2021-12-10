# Praxis Pure Nix Test Suite: Radix Trie & Longest Prefix Match (LPM)

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  trie = lib.trie;

in
runner.runSuite "trie" [
  (runner.testCase "empty_trie" (_:
    trie.isEmpty trie.empty
  ))

  (runner.testCase "insert_and_exact_lookup" (_:
    let
      t0 = trie.empty;
      t1 = trie.insert "10.0." "network-10" t0;
      t2 = trie.insert "192.168." "network-192" t1;
    in
    (trie.lookupExact "10.0." t2).found &&
    (trie.lookupExact "10.0." t2).value == "network-10" &&
    (trie.lookupExact "192.168." t2).value == "network-192" &&
    !(trie.lookupExact "172.16." t2).found
  ))

  (runner.testCase "longest_prefix_match_routing" (_:
    let
      # Route table:
      # "10."        -> "default-gw"
      # "10.1."      -> "regional-gw"
      # "10.1.2."    -> "local-subnet-gw"
      t0 = trie.fromList [
        { key = "10."; value = "default-gw"; }
        { key = "10.1."; value = "regional-gw"; }
        { key = "10.1.2."; value = "local-subnet-gw"; }
      ];

      # Match most specific prefix "10.1.2."
      match1 = trie.lookupLPM "10.1.2.45" t0;
      # Match intermediate prefix "10.1."
      match2 = trie.lookupLPM "10.1.99.1" t0;
      # Match default prefix "10."
      match3 = trie.lookupLPM "10.5.0.1" t0;
      # No match
      match4 = trie.lookupLPM "172.16.0.1" t0;
    in
    match1.found && match1.matchedPrefix == "10.1.2." && match1.value == "local-subnet-gw" &&
    match2.found && match2.matchedPrefix == "10.1." && match2.value == "regional-gw" &&
    match3.found && match3.matchedPrefix == "10." && match3.value == "default-gw" &&
    !match4.found
  ))
]
