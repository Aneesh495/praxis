# Praxis Pure Nix Standard Library
# Kahn's Topological Sort and Parallel Level Scheduler
#
# Computes deterministic topological orderings and parallel activation levels
# for Directed Acyclic Graphs (DAGs). Used for task orchestration, systemd unit
# sequencing, database migration sequences, and package derivation closures.

rec {
  # Computes topological sort using Kahn's algorithm.
  # graph: Attribute set mapping node to list of prerequisites (incoming edges).
  # e.g. { "build" = [ "compile" "test" ]; "compile" = []; "test" = [ "compile" ]; }
  # Returns:
  # {
  #   success = bool;
  #   order = [ "compile" "test" "build" ];
  #   levels = [ [ "compile" ] [ "test" ] [ "build" ] ];
  #   cycle = [ ... ];
  # }
  sort = graph:
    let
      allNodes = builtins.attrNames graph;

      # Compute in-degrees (count of dependencies each node waits on)
      inDegrees = builtins.foldl' (acc: node:
        let
          deps = if builtins.hasAttr node graph then graph.${node} else [];
          # Only count dependencies that exist in graph
          validDeps = builtins.filter (d: builtins.hasAttr d graph) deps;
        in
        acc // { ${node} = builtins.length validDeps; }
      ) {} allNodes;

      # Compute forward adjacency (reverse edges: dep -> list of dependents)
      dependents = builtins.foldl' (acc: node:
        let
          deps = if builtins.hasAttr node graph then graph.${node} else [];
        in
        builtins.foldl' (innerAcc: dep:
          let
            curr = if builtins.hasAttr dep innerAcc then innerAcc.${dep} else [];
          in
          innerAcc // { ${dep} = curr ++ [ node ]; }
        ) acc deps
      ) {} allNodes;

      # Level-by-level iteration
      go = currentInDegrees: remainingNodes: levelsAcc: orderAcc:
        # Find all nodes with in-degree 0
        let
          zeroDegreeNodes = builtins.filter (n:
            currentInDegrees.${n} == 0
          ) remainingNodes;
        in
        if zeroDegreeNodes == [] then
          if remainingNodes == [] then
            # Successfully sorted all nodes
            {
              success = true;
              order = orderAcc;
              levels = levelsAcc;
              cycle = [];
            }
          else
            # Cycle detected: remainingNodes form one or more cyclic dependencies
            {
              success = false;
              order = orderAcc;
              levels = levelsAcc;
              cycle = remainingNodes;
            }
        else
          # Decrement in-degrees of all dependent nodes
          let
            nextInDegrees = builtins.foldl' (degAcc: node:
              let
                nodeDeps = if builtins.hasAttr node dependents then dependents.${node} else [];
              in
              builtins.foldl' (innerDegAcc: depNode:
                if builtins.hasAttr depNode innerDegAcc then
                  innerDegAcc // { ${depNode} = innerDegAcc.${depNode} - 1; }
                else
                  innerDegAcc
              ) degAcc nodeDeps
            ) currentInDegrees zeroDegreeNodes;

            nextRemaining = builtins.filter (n: !builtins.elem n zeroDegreeNodes) remainingNodes;
          in
          go nextInDegrees nextRemaining (levelsAcc ++ [ zeroDegreeNodes ]) (orderAcc ++ zeroDegreeNodes);
    in
    go inDegrees allNodes [] [];
}
