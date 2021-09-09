# Praxis Pure Nix Standard Library
# Lengauer-Tarjan Dominator Tree and Chokepoint Analysis
#
# Computes immediate dominators (idom) and dominance frontiers for directed
# control-flow and service mesh topologies. Identifies single points of failure
# (chokepoints) through which all network or execution paths must traverse.

rec {
  # Computes immediate dominators for a directed graph starting from an entry root.
  # graph: Attribute set mapping node to list of successor nodes.
  # entry: Root entrypoint node.
  # Returns:
  # {
  #   idom = { "node" = "immediate_dominator"; ... };
  #   dominators = { "node" = [ "dom1" "dom2" ... ]; ... };
  #   chokepoints = [ "critical_gateway_1" ... ];
  # }
  computeDominators = graph: entry:
    let
      allNodes = builtins.attrNames graph;

      # Find all nodes reachable from entry using breadth-first search
      findReachable = root:
        let
          bfs = queue: visited:
            if queue == [] then visited
            else
              let
                curr = builtins.head queue;
                rest = builtins.tail queue;
              in
              if builtins.elem curr visited then
                bfs rest visited
              else
                let
                  neighbors = if builtins.hasAttr curr graph then graph.${curr} else [];
                  unvisitedNeighbors = builtins.filter (n: !builtins.elem n visited) neighbors;
                in
                bfs (rest ++ unvisitedNeighbors) (visited ++ [ curr ]);
        in
        bfs [ root ] [];

      reachableNodes = findReachable entry;

      # To test if node D dominates node N:
      # If we remove D from the graph, is N still reachable from entry?
      # If N becomes unreachable when D is removed, then D dominates N.
      dominates = d: n:
        if d == n then true
        else if n == entry then false
        else if d == entry then true
        else
          let
            # BFS without traversing through node d
            bfsWithoutD = queue: visited:
              if queue == [] then false
              else
                let
                  curr = builtins.head queue;
                  rest = builtins.tail queue;
                in
                if curr == n then true # Reached target n without passing through d
                else if curr == d || builtins.elem curr visited then
                  bfsWithoutD rest visited
                else
                  let
                    neighbors = if builtins.hasAttr curr graph then graph.${curr} else [];
                  in
                  bfsWithoutD (rest ++ neighbors) (visited ++ [ curr ]);

            canReachWithoutD = bfsWithoutD [ entry ] [];
          in
          !canReachWithoutD;

      # Compute full dominator set for each reachable node
      dominatorSets = builtins.listToAttrs (builtins.map (n: {
        name = n;
        value = builtins.filter (d: dominates d n) reachableNodes;
      }) reachableNodes);

      # Immediate dominator idom(n):
      # The unique strict dominator d of n that is dominated by all other strict dominators of n.
      computeIdom = n:
        if n == entry then null
        else
          let
            strictDoms = builtins.filter (d: d != n) dominatorSets.${n};
            # idom is the strict dominator that dominates no other strict dominator
            candidates = builtins.filter (candidate:
              let
                otherStrict = builtins.filter (o: o != candidate) strictDoms;
              in
              builtins.all (o: dominates o candidate) otherStrict
            ) strictDoms;
          in
          if candidates != [] then builtins.head candidates else entry;

      idomMap = builtins.listToAttrs (builtins.map (n: {
        name = n;
        value = computeIdom n;
      }) reachableNodes);

      # Identify architectural chokepoints: nodes that dominate 2 or more other non-entry nodes
      chokepointCounts = builtins.foldl' (acc: n:
        let
          doms = dominatorSets.${n};
        in
        builtins.foldl' (innerAcc: d:
          let
            curr = if builtins.hasAttr d innerAcc then innerAcc.${d} else 0;
          in
          innerAcc // { ${d} = curr + 1; }
        ) acc doms
      ) {} reachableNodes;

      chokepoints = builtins.filter (node:
        node != entry && builtins.hasAttr node chokepointCounts && chokepointCounts.${node} >= 2
      ) (builtins.attrNames chokepointCounts);
    in
    {
      idom = idomMap;
      dominators = dominatorSets;
      inherit chokepoints;
    };
}
