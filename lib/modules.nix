# Praxis Pure Nix Standard Library
# Lazy Module System, Priority Merging, and Semi-Lattice Evaluation
#
# Implements the full Praxis configuration evaluation engine. Supports:
# 1. Option declarations (mkOption, mkEnableOption)
# 2. Priority modifiers (mkOverride, mkForce, mkDefault)
# 3. Structural lazy option merging and fixpoint tying
# 4. Type checking contracts and assertion verifications

{ lib ? null }:

let
  types = import ./types.nix { inherit lib; };

  # Priority constants
  defaultPriority = 100;
  forcePriority = 50;
  fallbackPriority = 1000;

  # Unpack an overridden value to extract its priority and payload
  dischargePriority = val:
    if builtins.isAttrs val && val ? _type && val._type == "override" then
      { priority = val.priority; content = val.content; }
    else
      { priority = defaultPriority; content = val; };

  # Deeply merge two attribute sets recursively
  deepMerge = a: b:
    if builtins.isAttrs a && builtins.isAttrs b then
      let
        allKeys = builtins.foldl' (acc: k:
          if builtins.elem k acc then acc else acc ++ [ k ]
        ) (builtins.attrNames a) (builtins.attrNames b);
      in
      builtins.listToAttrs (builtins.map (k: {
        name = k;
        value =
          if builtins.hasAttr k a && builtins.hasAttr k b then
            deepMerge a.${k} b.${k}
          else if builtins.hasAttr k a then
            a.${k}
          else
            b.${k};
      }) allKeys)
    else
      b;

in
rec {
  inherit types;

  # Declare an option within a module schema.
  # args:
  # - type: Option type from types.*
  # - default: Default value if not specified
  # - defaultText: Optional human-readable description of default
  # - example: Example usage
  # - description: Detailed documentation of option purpose
  mkOption = {
    type ? types.str,
    default ? null,
    hasDefault ? (default != null),
    defaultText ? null,
    example ? null,
    description ? "",
  }: {
    _type = "option";
    inherit type default hasDefault defaultText example description;
  };

  # Convenience constructor for boolean enable options.
  mkEnableOption = name: mkOption {
    type = types.bool;
    default = false;
    hasDefault = true;
    example = true;
    description = "Whether to enable ${name}.";
  };

  # Wrap a value with an explicit priority level.
  # Lower priority numbers take precedence over higher numbers.
  mkOverride = priority: content: {
    _type = "override";
    inherit priority content;
  };

  # Wrap a value with forced priority (priority 50).
  mkForce = content: mkOverride forcePriority content;

  # Wrap a value with fallback priority (priority 1000).
  mkDefault = content: mkOverride fallbackPriority content;

  # Check if a value is an option declaration.
  isOption = v: builtins.isAttrs v && v ? _type && v._type == "option";

  # Evaluates a collection of modules into a unified configuration fixed point.
  # args:
  # - modules: List of module attribute sets or functions
  # - specialArgs: Extra arguments to pass into functional modules
  evalModules = { modules, specialArgs ? {} }:
    let
      # Fixpoint definition: config references itself through the lazy evaluation
      fixpoint = self:
        let
          # Context passed to every functional module
          moduleContext = specialArgs // {
            config = self.config;
            options = self.options;
            lib = if lib != null then lib else (import ./default.nix {});
          };

          # Normalize all modules to raw attribute sets
          normalizedModules = builtins.map (m:
            if builtins.isFunction m then
              m moduleContext
            else if builtins.isAttrs m then
              m
            else
              throw "Praxis evalModules: invalid module type: expected function or attrs"
          ) modules;

          # Extract sub-modules imported via imports = [ ... ]
          resolveImports = mods:
            builtins.concatMap (m:
              let
                subImports = if m ? imports then resolveImports m.imports else [];
              in
              [ m ] ++ subImports
            ) mods;

          allModules = resolveImports normalizedModules;

          # Separate options declarations and config definitions
          collectedOptions = builtins.foldl' (acc: m:
            if m ? options then deepMerge acc m.options else acc
          ) {} allModules;

          collectedConfigs = builtins.concatMap (m:
            if m ? config then [ m.config ]
            else
              # Strip meta keys if top-level attrs represent config directly
              let
                clean = builtins.removeAttrs m [ "options" "imports" "warnings" "assertions" ];
              in
              if clean != {} then [ clean ] else []
          ) allModules;

          # Collect assertions and warnings across modules
          collectedAssertions = builtins.concatMap (m:
            if m ? assertions then m.assertions
            else if m ? config && m.config ? assertions then m.config.assertions
            else []
          ) allModules;

          collectedWarnings = builtins.concatMap (m:
            if m ? warnings then m.warnings
            else if m ? config && m.config ? warnings then m.config.warnings
            else []
          ) allModules;

          # Recursive option and config resolver
          resolveTree = prefix: optTree: defTrees:
            let
              optKeys = builtins.attrNames optTree;
              defKeys = builtins.foldl' (acc: d:
                if builtins.isAttrs d then
                  acc ++ (builtins.filter (k: !builtins.elem k acc) (builtins.attrNames d))
                else
                  acc
              ) [] defTrees;

              allKeys = builtins.foldl' (acc: k:
                if builtins.elem k acc then acc else acc ++ [ k ]
              ) optKeys defKeys;
            in
            builtins.listToAttrs (builtins.map (key:
              let
                loc = prefix ++ [ key ];
                locStr = builtins.concatStringsSep "." loc;
                hasOpt = builtins.hasAttr key optTree;
                optNode = if hasOpt then optTree.${key} else null;

                # Gather definitions for this specific key
                keyDefs = builtins.concatMap (d:
                  if builtins.isAttrs d && builtins.hasAttr key d then
                    let
                      discharged = dischargePriority d.${key};
                    in
                    [ { file = "module"; priority = discharged.priority; value = discharged.content; } ]
                  else
                    []
                ) defTrees;
              in
              if hasOpt && isOption optNode then
                # Terminal option node: perform priority resolution and type check
                let
                  opt = optNode;
                  # Filter definitions to find highest priority (lowest number)
                  resolvedValue =
                    if keyDefs == [] then
                      if opt.hasDefault then opt.default
                      else throw "Praxis: mandatory option '${locStr}' has no value and no default."
                    else
                      # Sort by priority
                      let
                        minPriority = builtins.foldl' (minP: d:
                          if d.priority < minP then d.priority else minP
                        ) 999999 keyDefs;

                        highestPriorityDefs = builtins.filter (d: d.priority == minPriority) keyDefs;
                      in
                      if builtins.length highestPriorityDefs == 1 then
                        (builtins.head highestPriorityDefs).value
                      else
                        # Merge multiple definitions with same priority via type.merge
                        opt.type.merge loc highestPriorityDefs;

                  # Validate against type contract
                  isValid = opt.type.check resolvedValue;
                in
                if !isValid then
                  throw "Praxis: option '${locStr}' value does not satisfy type contract '${opt.type.name}'"
                else
                  { name = key; value = resolvedValue; }
              else
                # Intermediate tree node: recurse
                let
                  subOptTree = if hasOpt && builtins.isAttrs optNode then optNode else {};
                  subDefTrees = builtins.filter builtins.isAttrs (builtins.map (d: d.value) keyDefs);
                in
                {
                  name = key;
                  value = resolveTree loc subOptTree subDefTrees;
                }
            ) allKeys);

          # Compute final configuration tree
          resolvedConfig = resolveTree [] collectedOptions collectedConfigs;

          # Verify all assertions
          failedAssertions = builtins.filter (a: !a.assertion) collectedAssertions;
          assertCheck =
            if failedAssertions != [] then
              let
                firstFail = builtins.head failedAssertions;
              in
              throw "Praxis Assertion Failed: ${firstFail.message}"
            else
              true;
        in
        assertCheck seq {
          config = resolvedConfig;
          options = collectedOptions;
          warnings = collectedWarnings;
          assertions = collectedAssertions;
        };

      # Instantiate fixed point
      evaluated = builtins.genericClosure or fix (fixpoint);
    in
    evaluated;
}
