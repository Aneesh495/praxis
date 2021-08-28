# Praxis Pure Nix Standard Library
# Functional Programming Primitives, Combinators, and Optics
#
# This module provides higher-order functional programming combinators,
# fixed-point computations, lens optics, and catamorphic folds implemented
# in pure Nix without external dependencies.

rec {
  # The Y-combinator for pure untyped lambda recursion.
  # Note: In a lazy language with native recursive bindings, native recursion is
  # typically preferred for performance, but yCombinator demonstrates formal
  # fixed-point semantics.
  yCombinator = f: (x: f (v: x x v)) (x: f (v: x x v));

  # Standard fixed-point combinator for open recursion and attribute set tying.
  # Given a function f that accepts its own result, fix computes the fixed point:
  # x = f x.
  fix = f: let result = f result; in result;

  # Identity function.
  id = x: x;

  # Constant function. Returns a function that always yields x.
  const = x: _: x;

  # Function composition: (f . g)(x) = f (g x).
  compose = f: g: x: f (g x);

  # Reverse function composition (piping): pipe x [f g h] = h (g (f x)).
  pipe = val: functions:
    builtins.foldl' (acc: fn: fn acc) val functions;

  # Currying: converts a function taking a two-element list into curried form.
  curry = f: a: b: f [ a b ];

  # Uncurrying: converts a curried two-argument function into one taking a list.
  uncurry = f: args: f (builtins.elemAt args 0) (builtins.elemAt args 1);

  # Argument flipping: flip f a b = f b a.
  flip = f: a: b: f b a;

  # Range generator: generates integer list [start .. end] inclusive.
  range = start: end:
    if start > end then []
    else [ start ] ++ (range (start + 1) end);

  # Strict left fold wrapper over builtins.foldl'.
  foldl' = builtins.foldl';

  # Right fold: foldr f z [x1, x2, ...] = f x1 (f x2 ... z).
  foldr = f: z: list:
    let
      len = builtins.length list;
      go = idx:
        if idx >= len then z
        else f (builtins.elemAt list idx) (go (idx + 1));
    in
    go 0;

  # Zip two lists together using a combining function f.
  zipWith = f: listA: listB:
    let
      lenA = builtins.length listA;
      lenB = builtins.length listB;
      minLen = if lenA < lenB then lenA else lenB;
      go = idx:
        if idx >= minLen then []
        else [ (f (builtins.elemAt listA idx) (builtins.elemAt listB idx)) ] ++ (go (idx + 1));
    in
    go 0;

  # Filter elements of a list by a predicate.
  filter = builtins.filter;

  # Map a function over a list.
  map = builtins.map;

  # List partitioning: splits list into { right = [...]; wrong = [...]; }.
  partition = pred: list:
    builtins.foldl' (acc: item:
      if pred item then
        acc // { right = acc.right ++ [ item ]; }
      else
        acc // { wrong = acc.wrong ++ [ item ]; }
    ) { right = []; wrong = []; } list;

  # Lens optics: a lens is defined by a getter and a setter.
  # lens : (s -> a) -> (a -> s -> s) -> Lens s a
  lens = getter: setter: {
    get = getter;
    set = setter;
  };

  # View: extract the focused value using a lens.
  view = l: target: l.get target;

  # Set: update the focused value using a lens.
  set = l: val: target: l.set val target;

  # Over: apply a transformation function to the focused value using a lens.
  over = l: fn: target: l.set (fn (l.get target)) target;

  # Attribute lens: focuses on a specific attribute key in an attribute set.
  attrLens = key: defaultVal: lens
    (attrs: if builtins.hasAttr key attrs then attrs.${key} else defaultVal)
    (val: attrs: attrs // { ${key} = val; });

  # Nested attribute lens: navigates a path of keys [ "a" "b" "c" ].
  pathLens = pathList: defaultVal:
    if pathList == [] then
      lens id (val: _: val)
    else
      let
        headKey = builtins.head pathList;
        tailKeys = builtins.tail pathList;
      in
      lens
        (attrs:
          if builtins.hasAttr headKey attrs then
            view (pathLens tailKeys defaultVal) attrs.${headKey}
          else
            defaultVal
        )
        (val: attrs:
          let
            subAttrs = if builtins.hasAttr headKey attrs then attrs.${headKey} else {};
            updatedSub = set (pathLens tailKeys defaultVal) val subAttrs;
          in
          attrs // { ${headKey} = updatedSub; }
        );

  # Catamorphism fold: decomposes an algebraic recursive structure.
  # algebra : F A -> A
  # cata : (F A -> A) -> Fix F -> A
  cata = algebra: term:
    algebra (builtins.mapAttrs (_: cata algebra) term);

  # Anamorphism unfold: generates an algebraic structure from a seed.
  # coalgebra : A -> F A
  # ana : (A -> F A) -> A -> Fix F
  ana = coalgebra: seed:
    builtins.mapAttrs (_: ana coalgebra) (coalgebra seed);

  # Hylomorphism: composition of anamorphism followed by catamorphism.
  # hylo : (F B -> B) -> (A -> F A) -> A -> B
  hylo = algebra: coalgebra: seed:
    cata algebra (ana coalgebra seed);
}
