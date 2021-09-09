# Praxis Pure Nix Standard Library
# Tarjan's Strongly Connected Components (SCC) Algorithm
#
# Computes all strongly connected components in directed graphs using Tarjan's
# depth-first search algorithm. Identifies circular dependencies in systemd unit
# graphs, service mesh routing topologies, and module dependency trees.

rec {
  # Computes Strongly Connected Components for a directed graph.
  # graph: Attribute set mapping node names to lists of target node names.
  # e.g. { "A" = [ "B" ]; "B" = [ "C" ]; "C" = [ "A" ]; "D" = []; }
  # Returns: List of components, where each component is a list of node names.
  scc = graph:
    let
      allNodes = builtins.attrNames graph;

      # DFS State:
      # - index: current integer counter for discovery time
      # - indices: attrset node -> discovery index
      # - lowlinks: attrset node -> lowlink value
      # - onStack: attrset node -> bool
      # - stack: list of nodes currently on call stack
      # - sccs: list of completed strongly connected components

      initialState = {
        index = 0;
        indices = {};
        lowlinks = {};
        onStack = {};
        stack = [];
        sccs = [];
      };

      strongConnect = node: state:
        let
          # Assign discovery index and lowlink
          s0 = state // {
            indices = state.indices // { ${node} = state.index; };
            lowlinks = state.lowlinks // { ${node} = state.index; };
            onStack = state.onStack // { ${node} = true; };
            stack = [ node ] ++ state.stack;
            index = state.index + 1;
          };

          neighbors = if builtins.hasAttr node graph then graph.${node} else [];

          # Traverse all outgoing edges
          sNeighbors = builtins.foldl' (currState: w:
            if !builtins.hasAttr w currState.indices then
              # Successor w has not yet been visited; recurse
              let
                sRec = strongConnect w currState;
                wLow = sRec.lowlinks.${w};
                currLow = sRec.lowlinks.${node};
                minLow = if wLow < currLow then wLow else currLow;
              in
              sRec // {
                lowlinks = sRec.lowlinks // { ${node} = minLow; };
              }
            else if builtins.hasAttr w currState.onStack && currState.onStack.${w} then
              # Successor w is on the stack and hence in current SCC
              let
                wIdx = currState.indices.${w};
                currLow = currState.lowlinks.${node};
                minLow = if wIdx < currLow then wIdx else currLow;
              in
              currState // {
                lowlinks = currState.lowlinks // { ${node} = minLow; };
              }
            else
              currState
          ) s0 neighbors;

          # If node is a root node, pop the stack and generate an SCC
          finalState =
            if sNeighbors.lowlinks.${node} == sNeighbors.indices.${node} then
              let
                # Pop nodes until node is reached
                popUntil = stk: acc:
                  if stk == [] then { newStack = []; comp = acc; }
                  else
                    let
                      top = builtins.head stk;
                      rest = builtins.tail stk;
                      newAcc = acc ++ [ top ];
                    in
                    if top == node then
                      { newStack = rest; comp = newAcc; }
                    else
                      popUntil rest newAcc;

                popped = popUntil sNeighbors.stack [];
                newOnStack = builtins.foldl' (acc: n:
                  acc // { ${n} = false; }
                ) sNeighbors.onStack popped.comp;
              in
              sNeighbors // {
                stack = popped.newStack;
                onStack = newOnStack;
                sccs = sNeighbors.sccs ++ [ popped.comp ];
              }
            else
              sNeighbors;
        in
        finalState;

      # Execute DFS from all unvisited nodes
      finalDfsState = builtins.foldl' (state: node:
        if !builtins.hasAttr node state.indices then
          strongConnect node state
        else
          state
      ) initialState allNodes;
    in
    finalDfsState.sccs;

  # Detects if a directed graph has any cycles.
  # Returns: { hasCycle = bool; cycles = [ ... ]; }
  detectCycles = graph:
    let
      components = scc graph;
      cycles = builtins.filter (comp:
        if builtins.length comp > 1 then true
        else if builtins.length comp == 1 then
          let
            node = builtins.head comp;
            neighbors = if builtins.hasAttr node graph then graph.${node} else [];
          in
          builtins.elem node neighbors # Self-loop
        else false
      ) components;
    in
    {
      hasCycle = (cycles != []);
      inherit cycles;
    };
}
