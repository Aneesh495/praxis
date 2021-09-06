# Praxis Pure Nix Standard Library
# Persistent Disjoint-Set Union (Union-Find)
#
# Implements a functional Disjoint-Set data structure with union-by-rank
# and path-compression semantics. Used for network partition analysis,
# cluster consensus failure domains, and spanning tree calculations.

rec {
  # Initialize a new Disjoint-Set structure with a list of element identifiers.
  init = elements: {
    parent = builtins.listToAttrs (builtins.map (e: { name = toString e; value = toString e; }) elements);
    rank = builtins.listToAttrs (builtins.map (e: { name = toString e; value = 0; }) elements);
    numComponents = builtins.length elements;
  };

  # Find operation: locates the root representative of element x.
  # Returns { root = str; dsu = updatedDsu; }.
  find = x: dsu:
    let
      xStr = toString x;
      parentOfX = if builtins.hasAttr xStr dsu.parent then dsu.parent.${xStr} else xStr;
    in
    if parentOfX == xStr then
      { root = xStr; inherit dsu; }
    else
      # Path compression: update parent pointer directly to root
      let
        recurse = find parentOfX dsu;
        newParent = recurse.dsu.parent // { ${xStr} = recurse.root; };
        updatedDsu = recurse.dsu // { parent = newParent; };
      in
      { root = recurse.root; dsu = updatedDsu; };

  # Union operation: merges the equivalence classes containing x and y.
  # Uses union-by-rank heuristic to attach shorter trees under taller roots.
  # Returns updated dsu structure.
  union = x: y: dsu:
    let
      resX = find x dsu;
      rootX = resX.root;
      dsuAfterX = resX.dsu;

      resY = find y dsuAfterX;
      rootY = resY.root;
      dsuAfterY = resY.dsu;
    in
    if rootX == rootY then
      dsuAfterY
    else
      let
        rankX = if builtins.hasAttr rootX dsuAfterY.rank then dsuAfterY.rank.${rootX} else 0;
        rankY = if builtins.hasAttr rootY dsuAfterY.rank then dsuAfterY.rank.${rootY} else 0;
      in
      if rankX < rankY then
        dsuAfterY // {
          parent = dsuAfterY.parent // { ${rootX} = rootY; };
          numComponents = dsuAfterY.numComponents - 1;
        }
      else if rankX > rankY then
        dsuAfterY // {
          parent = dsuAfterY.parent // { ${rootY} = rootX; };
          numComponents = dsuAfterY.numComponents - 1;
        }
      else
        dsuAfterY // {
          parent = dsuAfterY.parent // { ${rootY} = rootX; };
          rank = dsuAfterY.rank // { ${rootX} = rankX + 1; };
          numComponents = dsuAfterY.numComponents - 1;
        };

  # Check whether x and y belong to the same connected component.
  # Returns { connected = bool; dsu = updatedDsu; }.
  connected = x: y: dsu:
    let
      resX = find x dsu;
      resY = find y resX.dsu;
    in
    {
      connected = (resX.root == resY.root);
      dsu = resY.dsu;
    };

  # Extract all connected components as an attribute set:
  # { root1 = [ elem1 elem2 ... ]; root2 = [ ... ]; }
  components = elements: dsu:
    let
      allElems = builtins.map toString elements;
      folded = builtins.foldl' (acc: elem:
        let
          res = find elem acc.dsu;
          currList = if builtins.hasAttr res.root acc.groups then acc.groups.${res.root} else [];
        in
        {
          dsu = res.dsu;
          groups = acc.groups // { ${res.root} = currList ++ [ elem ]; };
        }
      ) { inherit dsu; groups = {}; } allElems;
    in
    folded.groups;
}
