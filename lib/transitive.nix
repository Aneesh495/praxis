# Praxis Pure Nix Standard Library
# Transitive Reduction and Transitive Closure over DAGs
#
# Computes the transitive closure (reachability matrix) and transitive reduction
# (minimal edge representation) for Directed Acyclic Graphs. Eliminates redundant
# dependency edges in systemd unit dependencies and build graph closures.

rec {
  # Computes the transitive closure of a DAG using Warshall's reachability algorithm.
  # graph: Attribute set mapping node to list of directly reachable nodes.
  # Returns: Attribute set mapping node to list of all transitively reachable nodes.
  closure = graph:
    let
      allNodes = builtins.attrNames graph;

      # Direct reachability map
      initialClosure = builtins.listToAttrs (builtins.map (n: {
        name = n;
        value = if builtins.hasAttr n graph then graph.${n} else [];
      }) allNodes);

      # Iterative fixed-point expansion
      step = current:
        let
          updated = builtins.listToAttrs (builtins.map (u: {
            name = u;
            value =
              let
                direct = current.${u};
                indirect = builtins.concatMap (v:
                  if builtins.hasAttr v current then current.${v} else []
                ) direct;
                combined = builtins.foldl' (acc: item:
                  if builtins.elem item acc then acc else acc ++ [ item ]
                ) direct indirect;
              in
              combined;
          }) allNodes);

          isEqual = builtins.all (n:
            builtins.length current.${n} == builtins.length updated.${n}
          ) allNodes;
        in
        if isEqual then current else step updated;
    in
    step initialClosure;

  # Computes the transitive reduction of a DAG.
  # Removes edge (u, v) if there exists another path from u to v of length >= 2.
  # Returns: Attribute set mapping node to minimal essential dependency list.
  reduction = graph:
    let
      allNodes = builtins.attrNames graph;
      reachability = closure graph;

      reduced = builtins.listToAttrs (builtins.map (u: {
        name = u;
        value =
          let
            directTargets = if builtins.hasAttr u graph then graph.${u} else [];
            # Keep edge u -> v only if NO other direct target w can reach v
            essential = builtins.filter (v:
              let
                alternativePaths = builtins.filter (w:
                  w != v && builtins.elem v (if builtins.hasAttr w reachability then reachability.${w} else [])
                ) directTargets;
              in
              alternativePaths == []
            ) directTargets;
          in
          essential;
      }) allNodes);
    in
    reduced;
}
