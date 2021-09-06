# Praxis Pure Nix Standard Library
# Persistent Red-Black Balanced Binary Search Tree
#
# Implements Okasaki's purely functional self-balancing Red-Black Tree in pure Nix.
# Guarantees logarithmic O(log N) worst-case time for insertions and lookups.
# Colors: "R" (Red) and "B" (Black). Empty tree is represented as null.

rec {
  # Empty tree constructor
  empty = null;

  # Node constructor: color, key, value, left, right
  node = color: key: value: left: right: {
    inherit color key value left right;
    _type = "rbtree-node";
  };

  # Check if a tree is empty
  isEmpty = tree: tree == null;

  # Okasaki balance function.
  # Rebalances four possible red-red violation configurations into a single balanced red node.
  # Config 1: Left-Left
  # Config 2: Left-Right
  # Config 3: Right-Left
  # Config 4: Right-Right
  balance = color: key: value: left: right:
    if color == "B" then
      if left != null && left.color == "R" && left.left != null && left.left.color == "R" then
        # Left-Left case
        let
          a = left.left.left;
          xKey = left.left.key;
          xVal = left.left.value;
          b = left.left.right;
          yKey = left.key;
          yVal = left.value;
          c = left.right;
          zKey = key;
          zVal = value;
          d = right;
        in
        node "R" yKey yVal (node "B" xKey xVal a b) (node "B" zKey zVal c d)

      else if left != null && left.color == "R" && left.right != null && left.right.color == "R" then
        # Left-Right case
        let
          a = left.left;
          xKey = left.key;
          xVal = left.value;
          b = left.right.left;
          yKey = left.right.key;
          yVal = left.right.value;
          c = left.right.right;
          zKey = key;
          zVal = value;
          d = right;
        in
        node "R" yKey yVal (node "B" xKey xVal a b) (node "B" zKey zVal c d)

      else if right != null && right.color == "R" && right.left != null && right.left.color == "R" then
        # Right-Left case
        let
          a = left;
          xKey = key;
          xVal = value;
          b = right.left.left;
          yKey = right.left.key;
          yVal = right.left.value;
          c = right.left.right;
          zKey = right.key;
          zVal = right.value;
          d = right.right;
        in
        node "R" yKey yVal (node "B" xKey xVal a b) (node "B" zKey zVal c d)

      else if right != null && right.color == "R" && right.right != null && right.right.color == "R" then
        # Right-Right case
        let
          a = left;
          xKey = key;
          xVal = value;
          b = right.left;
          yKey = right.key;
          yVal = right.value;
          c = right.right.left;
          zKey = right.right.key;
          zVal = right.right.value;
          d = right.right.right;
        in
        node "R" yKey yVal (node "B" xKey xVal a b) (node "B" zKey zVal c d)

      else
        node color key value left right
    else
      node color key value left right;

  # Insert a key-value pair into the Red-Black Tree.
  # Comparison uses standard Nix ordering (<, >, ==).
  insert = key: value: tree:
    let
      ins = t:
        if t == null then
          node "R" key value null null
        else if key < t.key then
          balance t.color t.key t.value (ins t.left) t.right
        else if key > t.key then
          balance t.color t.key t.value t.left (ins t.right)
        else
          # Update existing key value
          node t.color key value t.left t.right;

      root = ins tree;
    in
    # Root property: root of a Red-Black Tree is always black
    node "B" root.key root.value root.left root.right;

  # Search for a key in the tree.
  # Returns { found = true; value = ...; } or { found = false; value = null; }.
  lookup = key: tree:
    if tree == null then
      { found = false; value = null; }
    else if key < tree.key then
      lookup key tree.left
    else if key > tree.key then
      lookup key tree.right
    else
      { found = true; value = tree.value; };

  # Check if a key exists in the tree.
  hasKey = key: tree: (lookup key tree).found;

  # In-order traversal converting tree to sorted list of { key = ...; value = ...; }.
  toList = tree:
    if tree == null then []
    else (toList tree.left) ++ [ { inherit (tree) key value; } ] ++ (toList tree.right);

  # Build a Red-Black Tree from an unsorted list of { key, value } pairs.
  fromList = list:
    builtins.foldl' (acc: item: insert item.key item.value acc) empty list;

  # Count total nodes in the tree.
  size = tree:
    if tree == null then 0
    else 1 + (size tree.left) + (size tree.right);

  # Compute maximum depth/height of the tree.
  height = tree:
    if tree == null then 0
    else
      let
        lh = height tree.left;
        rh = height tree.right;
      in
      1 + (if lh > rh then lh else rh);

  # Find minimum key-value pair.
  minNode = tree:
    if tree == null then null
    else if tree.left == null then { inherit (tree) key value; }
    else minNode tree.left;

  # Find maximum key-value pair.
  maxNode = tree:
    if tree == null then null
    else if tree.right == null then { inherit (tree) key value; }
    else maxNode tree.right;

  # Verifies Red-Black Tree invariant:
  # 1. Root is Black.
  # 2. No Red node has a Red child.
  # 3. Every path from root to leaf contains equal number of Black nodes.
  isBalanced = tree:
    if tree == null then true
    else
      let
        # Check no red-red violations
        noRedRed = t:
          if t == null then true
          else if t.color == "R" then
            (t.left == null || t.left.color == "B") &&
            (t.right == null || t.right.color == "B") &&
            noRedRed t.left && noRedRed t.right
          else
            noRedRed t.left && noRedRed t.right;

        # Compute black height and ensure all branches match
        blackHeight = t:
          if t == null then 1
          else
            let
              lb = blackHeight t.left;
              rb = blackHeight t.right;
            in
            if lb == -1 || rb == -1 || lb != rb then -1
            else lb + (if t.color == "B" then 1 else 0);
      in
      tree.color == "B" && noRedRed tree && (blackHeight tree != -1);
}
