# Praxis Pure Nix Standard Library
# Dijkstra and Bellman-Ford Shortest Path Routing Algorithms
#
# Computes shortest paths, optimal next-hop routing tables, and network latency
# distance matrices across service mesh topologies and WireGuard overlay networks.

rec {
  # Dijkstra's Algorithm for single-source shortest paths on non-negative weighted graphs.
  # graph: Attribute set mapping node to list of { node = target; weight = int; }
  # source: Starting node name
  # Returns:
  # {
  #   distances = { "A" = 0; "B" = 5; "C" = 12; ... };
  #   previous = { "B" = "A"; "C" = "B"; ... };
  #   routingTable = { "B" = "B"; "C" = "B"; ... }; # Next hop from source
  # }
  dijkstra = graph: source:
    let
      allNodes = builtins.attrNames graph;
      infinity = 1000000000;

      initialDistances = builtins.listToAttrs (builtins.map (n: {
        name = n;
        value = if n == source then 0 else infinity;
      }) allNodes);

      initialPrevious = builtins.listToAttrs (builtins.map (n: {
        name = n;
        value = null;
      }) allNodes);

      # Iterative relaxation
      step = unvisited: distances: previous:
        if unvisited == [] then
          { inherit distances previous; }
        else
          # Find node in unvisited with minimal distance
          let
            minNode = builtins.foldl' (best: curr:
              let
                dCurr = distances.${curr};
                dBest = if best == null then infinity else distances.${best};
              in
              if dCurr < dBest then curr else best
            ) null unvisited;
          in
          if minNode == null || distances.${minNode} >= infinity then
            # All remaining unvisited nodes are unreachable
            { inherit distances previous; }
          else
            let
              currentDist = distances.${minNode};
              edges = if builtins.hasAttr minNode graph then graph.${minNode} else [];
              unvisitedNext = builtins.filter (n: n != minNode) unvisited;

              # Relax edges
              relaxed = builtins.foldl' (acc: edge:
                let
                  target = edge.node;
                  weight = edge.weight;
                  newDist = currentDist + weight;
                in
                if builtins.hasAttr target acc.dist && newDist < acc.dist.${target} then
                  {
                    dist = acc.dist // { ${target} = newDist; };
                    prev = acc.prev // { ${target} = minNode; };
                  }
                else
                  acc
              ) { dist = distances; prev = previous; } edges;
            in
            step unvisitedNext relaxed.dist relaxed.prev;

      res = step allNodes initialDistances initialPrevious;

      # Reconstruct next-hop routing table from source
      computeNextHop = dest:
        if dest == source then source
        else if res.previous.${dest} == null then null
        else if res.previous.${dest} == source then dest
        else computeNextHop res.previous.${dest};

      routingTable = builtins.listToAttrs (builtins.map (dest: {
        name = dest;
        value = computeNextHop dest;
      }) allNodes);
    in
    {
      distances = res.distances;
      previous = res.previous;
      inherit routingTable;
    };

  # Reconstruct full shortest path from source to destination:
  # [ source ... intermediate ... dest ]
  reconstructPath = previous: source: dest:
    let
      go = curr: acc:
        if curr == null then []
        else if curr == source then [ source ] ++ acc
        else
          let
            prev = if builtins.hasAttr curr previous then previous.${curr} else null;
          in
          go prev ([ curr ] ++ acc);
    in
    go dest [];
}
