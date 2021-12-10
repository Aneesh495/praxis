# Praxis Pure Nix Test Suite: Leftist Priority Queue (Heap)

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  heap = lib.heap;

in
runner.runSuite "heap" [
  (runner.testCase "empty_heap" (_:
    heap.isEmpty heap.empty && heap.size heap.empty == 0
  ))

  (runner.testCase "push_and_peek_min" (_:
    let
      h0 = heap.empty;
      h1 = heap.push 50 "job50" h0;
      h2 = heap.push 10 "job10" h1;
      h3 = heap.push 30 "job30" h2;
      top = heap.peek h3;
    in
    top.found && top.priority == 10 && top.value == "job10"
  ))

  (runner.testCase "pop_elements_in_priority_order" (_:
    let
      items = [
        { priority = 80; value = "low"; }
        { priority = 10; value = "critical"; }
        { priority = 40; value = "medium"; }
      ];
      h = heap.fromList items;
      p1 = heap.pop h;
      p2 = heap.pop p1.rest;
      p3 = heap.pop p2.rest;
      p4 = heap.pop p3.rest;
    in
    p1.item.priority == 10 &&
    p2.item.priority == 40 &&
    p3.item.priority == 80 &&
    p4 == null
  ))

  (runner.testCase "heapsort_verification" (_:
    let
      input = [
        { priority = 5; value = "e"; }
        { priority = 1; value = "a"; }
        { priority = 3; value = "c"; }
        { priority = 2; value = "b"; }
        { priority = 4; value = "d"; }
      ];
      h = heap.fromList input;
      sorted = heap.toSortedList h;
      priorities = builtins.map (item: item.priority) sorted;
    in
    priorities == [ 1 2 3 4 5 ]
  ))
]
