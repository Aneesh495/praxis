# Praxis Pure Nix Standard Library
# Persistent Leftist Priority Queue (Min-Heap and Max-Heap)
#
# Implements Okasaki's purely functional Leftist Heap in pure Nix.
# Guarantees O(1) peek and O(log N) insertion, merge, and pop operations.
# Nodes maintain the leftist property: rank(left) >= rank(right).

rec {
  # Empty heap representation
  empty = null;

  # Node constructor: rank, priority, value, left, right
  mkNode = rank: priority: value: left: right: {
    inherit rank priority value left right;
    _type = "leftist-heap-node";
  };

  # Check if heap is empty
  isEmpty = heap: heap == null;

  # Rank of a node (distance to nearest external leaf along right spine)
  rankOf = heap:
    if heap == null then 0 else heap.rank;

  # Merge two min-heaps into a single leftist heap in O(log N) steps.
  # Elements with smaller numerical priority values have higher precedence.
  mergeMin = h1: h2:
    if h1 == null then h2
    else if h2 == null then h1
    else
      let
        # Choose smaller root as new root
        primary = if h1.priority <= h2.priority then h1 else h2;
        secondary = if h1.priority <= h2.priority then h2 else h1;

        # Merge secondary with right sub-tree
        mergedRight = mergeMin primary.right secondary;

        # Maintain leftist rank invariant: rank(left) >= rank(right)
        leftRank = rankOf primary.left;
        rightRank = rankOf mergedRight;
      in
      if leftRank >= rightRank then
        mkNode (rightRank + 1) primary.priority primary.value primary.left mergedRight
      else
        mkNode (leftRank + 1) primary.priority primary.value mergedRight primary.left;

  # Merge two max-heaps (larger priority values have higher precedence).
  mergeMax = h1: h2:
    if h1 == null then h2
    else if h2 == null then h1
    else
      let
        primary = if h1.priority >= h2.priority then h1 else h2;
        secondary = if h1.priority >= h2.priority then h2 else h1;
        mergedRight = mergeMax primary.right secondary;
        leftRank = rankOf primary.left;
        rightRank = rankOf mergedRight;
      in
      if leftRank >= rightRank then
        mkNode (rightRank + 1) primary.priority primary.value primary.left mergedRight
      else
        mkNode (leftRank + 1) primary.priority primary.value mergedRight primary.left;

  # Insert an item with given priority into min-heap.
  push = priority: value: heap:
    let
      singleton = mkNode 1 priority value null null;
    in
    mergeMin singleton heap;

  # Insert an item with given priority into max-heap.
  pushMax = priority: value: heap:
    let
      singleton = mkNode 1 priority value null null;
    in
    mergeMax singleton heap;

  # Peek at minimum priority item without removing it.
  # Returns { found = true; priority = ...; value = ...; } or { found = false; ... }.
  peek = heap:
    if heap == null then
      { found = false; priority = null; value = null; }
    else
      { found = true; priority = heap.priority; value = heap.value; };

  # Pop minimum priority item from min-heap.
  # Returns { item = { priority = ...; value = ...; }; rest = ...; } or null if empty.
  pop = heap:
    if heap == null then null
    else {
      item = { priority = heap.priority; value = heap.value; };
      rest = mergeMin heap.left heap.right;
    };

  # Pop maximum priority item from max-heap.
  popMax = heap:
    if heap == null then null
    else {
      item = { priority = heap.priority; value = heap.value; };
      rest = mergeMax heap.left heap.right;
    };

  # Count total elements in heap.
  size = heap:
    if heap == null then 0
    else 1 + (size heap.left) + (size heap.right);

  # Build min-heap from a list of { priority, value } items.
  fromList = list:
    builtins.foldl' (acc: item: push item.priority item.value acc) empty list;

  # Convert heap to a sorted list by repeatedly popping root.
  toSortedList = heap:
    let
      go = h:
        let
          p = pop h;
        in
        if p == null then []
        else [ p.item ] ++ (go p.rest);
    in
    go heap;
}
