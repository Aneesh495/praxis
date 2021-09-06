# Praxis Pure Nix Standard Library
# Persistent Radix Trie and Longest Prefix Match (LPM) Routing Engine
#
# Implements a functional trie structure optimized for string prefixes and
# binary IP routing prefixes. Supports exact key lookup and Longest Prefix
# Match (LPM) queries used in WireGuard mesh and eBPF routing tables.

rec {
  # Empty trie constructor
  empty = {
    hasValue = false;
    value = null;
    children = {};
  };

  # Node constructor
  mkNode = hasValue: value: children: {
    inherit hasValue value children;
    _type = "radix-trie-node";
  };

  # Check if a trie node is completely empty
  isEmpty = trie:
    trie == null || (!trie.hasValue && trie.children == {});

  # Insert a string key and its associated value into the trie.
  # Returns a new trie node.
  insert = key: value: trie:
    let
      len = builtins.stringLength key;
      go = idx: node:
        if idx >= len then
          mkNode true value node.children
        else
          let
            char = builtins.substring idx 1 key;
            childNode =
              if builtins.hasAttr char node.children then
                node.children.${char}
              else
                empty;
            updatedChild = go (idx + 1) childNode;
          in
          mkNode node.hasValue node.value (node.children // { ${char} = updatedChild; });
    in
    go 0 (if trie == null then empty else trie);

  # Exact key lookup.
  # Returns { found = true; value = ...; } or { found = false; value = null; }.
  lookupExact = key: trie:
    if trie == null then
      { found = false; value = null; }
    else
      let
        len = builtins.stringLength key;
        go = idx: node:
          if idx >= len then
            if node.hasValue then { found = true; value = node.value; }
            else { found = false; value = null; }
          else
            let
              char = builtins.substring idx 1 key;
            in
            if builtins.hasAttr char node.children then
              go (idx + 1) node.children.${char}
            else
              { found = false; value = null; };
      in
      go 0 trie;

  # Longest Prefix Match (LPM).
  # Used for network route selection: finds the most specific route matching
  # the destination prefix.
  # Returns { found = true; matchedPrefix = ...; value = ...; } or { found = false; ... }.
  lookupLPM = key: trie:
    if trie == null then
      { found = false; matchedPrefix = ""; value = null; }
    else
      let
        len = builtins.stringLength key;
        go = idx: node: bestPrefix: bestVal:
          let
            currentPrefix = builtins.substring 0 idx key;
            newBestPrefix = if node.hasValue then currentPrefix else bestPrefix;
            newBestVal = if node.hasValue then node.value else bestVal;
            hasNewBest = node.hasValue || (bestPrefix != "");
          in
          if idx >= len then
            if hasNewBest then
              { found = true; matchedPrefix = newBestPrefix; value = newBestVal; }
            else
              { found = false; matchedPrefix = ""; value = null; }
          else
            let
              char = builtins.substring idx 1 key;
            in
            if builtins.hasAttr char node.children then
              go (idx + 1) node.children.${char} newBestPrefix newBestVal
            else if hasNewBest then
              { found = true; matchedPrefix = newBestPrefix; value = newBestVal; }
            else
              { found = false; matchedPrefix = ""; value = null; };
      in
      go 0 trie "" null;

  # Convert all prefix-value pairs in the trie to a list.
  toList = trie:
    if trie == null then []
    else
      let
        go = prefix: node:
          let
            currentList =
              if node.hasValue then [ { key = prefix; value = node.value; } ]
              else [];
            childKeys = builtins.attrNames node.children;
            childrenLists = builtins.concatMap (char:
              go (prefix + char) node.children.${char}
            ) childKeys;
          in
          currentList ++ childrenLists;
      in
      go "" trie;

  # Build a trie from a list of { key = ...; value = ...; }.
  fromList = list:
    builtins.foldl' (acc: item: insert item.key item.value acc) empty list;
}
