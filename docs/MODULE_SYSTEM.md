# Praxis Declarative Module System

The Praxis module system provides an algebraic, strongly typed configuration language implemented in pure Nix. It extends classical fixed-point module semantics with bounded semi-lattice option resolution, structural type constraints, and topological assertion evaluation.

```
+========================================================================================+
|                              MODULE MERGING SEMI-LATTICE                               |
+========================================================================================+
|                                                                                        |
|         Priority Tier 50: mkForce (Overwrites all lower tiers unconditionally)         |
|                                       ^                                                |
|                                       |                                                |
|         Priority Tier 100: Default definitions (Normal user module declarations)       |
|                                       ^                                                |
|                                       |                                                |
|         Priority Tier 1000: mkDefault (Fallback defaults; easily overridden)           |
|                                                                                        |
|                                                                                        |
|   +-----------------------+                         +----------------------+           |
|   |   Module A (User)     |                         |   Module B (Base)    |           |
|   |  memory_mb = 8192     |                         |  memory_mb = 2048    |           |
|   |  (Priority 100)       |                         |  (mkDefault 1000)    |           |
|   +-----------+-----------+                         +----------+-----------+           |
|               |                                                |                       |
|               +----------------------+  +----------------------+                       |
|                                      |  |                                              |
|                                      v  v                                              |
|                           +-----------------------+                                    |
|                           | Semi-Lattice Resolver |                                    |
|                           |  Filters max priority |                                    |
|                           +-----------+-----------+                                    |
|                                       |                                                |
|                                       v                                                |
|                           +-----------------------+                                    |
|                           | Final Evaluated State |                                    |
|                           |  memory_mb = 8192     |                                    |
|                           +-----------------------+                                    |
+========================================================================================+
```

---

## 1. Mathematical Foundations: Bounded Semi-Lattices

A configuration option within Praxis represents an element in a partially ordered set (poset) $(S, \le)$ equipped with a binary join operator $\sqcup$:

$$a \sqcup b = \sup \{a, b\}$$

For configuration resolution to be deterministic and order-independent, the join operation must satisfy three algebraic properties:

1. **Idempotence**: $a \sqcup a = a$ (Declaring identical configurations yields the same result).
2. **Commutativity**: $a \sqcup b = b \sqcup a$ (The order of module imports does not alter the merged result).
3. **Associativity**: $(a \sqcup b) \sqcup c = a \sqcup (b \sqcup c)$ (Nested module trees evaluate identically regardless of grouping).

### Priority Function and Dominance Ordering
Each declared value $v$ carries a priority weight $p \in \mathbb{N}$:

$$\text{value}(v, p) \sqcup \text{value}(w, q) = \begin{cases} \text{value}(v, p) & \text{if } p < q \\ \text{value}(w, q) & \text{if } q < p \\ \text{merge}(v, w) & \text{if } p = q \end{cases}$$

- **`mkForce` ($p = 50$)**: Dominates standard declarations, allowing explicit administrative overrides.
- **Normal ($p = 100$)**: Standard declarations introduced by system profiles and service configurations.
- **`mkDefault` ($p = 1000$)**: Baseline defaults supplied by framework profiles, superseded by any explicit definition.

When two declarations share the exact same priority $p$:
- **Primitive scalars** (integers, strings, booleans): A conflict error is raised unless the values are structurally identical.
- **List collections**: Concatenated preserving declaration order.
- **Attribute sets**: Recursively merged down the key hierarchy.

---

## 2. Fixed-Point Computation (`fix` and `evalModules`)

In complex infrastructures, configurations exhibit cyclic references: Module A needs the IP address of Module B, while Module B needs the public key of Module A. Praxis resolves these mutual dependencies using the mathematical fixed point combinator.

Given a generator function $f: \text{Config} \to \text{Config}$, the fixed point $x^* = \text{fix}(f)$ satisfies:

$$x^* = f(x^*)$$

In pure Nix, lazy evaluation allows computing this fixed point without infinite recursion, provided that individual fields are not cyclically dependent on their own values:

```nix
fix = f:
  let result = f result;
  in result;
```

`evalModules` applies this fixed point across the entire graph of imported modules:

```nix
evalModules = { modules, args ? {} }:
  let
    # Fixed point binding tying configuration back to module inputs
    eval = fix (self:
      let
        collected = collectModules modules self.config;
        mergedConfig = mergeDefinitions collected.options collected.definitions;
        failedAssertions = filter (a: !a.assertion) mergedConfig.assertions;
      in
      if failedAssertions != [] then
        throw "Praxis assertion failure: ${head failedAssertions.message}"
      else
        {
          options = collected.options;
          config = mergedConfig;
        }
    );
  in eval;
```

---

## 3. Structural Type System and Contract Enforcement

Praxis features a comprehensive runtime contract verification system defined in `lib/types.nix`. Every module option is decorated with a type specification that guards against invalid configuration shapes at evaluation time.

### 3.1 Primitive Types
- `types.bool`: Boolean true or false.
- `types.int`: Integer values.
- `types.str`: UTF-8 string values.
- `types.attrsOf type`: Key-value dictionaries with homogeneous value types.
- `types.listOf type`: Ordered sequences with homogeneous element types.

### 3.2 Refined Domain Types
Praxis introduces specialized refined types that perform semantic validation:

```nix
# Network Port Contract: 1 <= port <= 65535
port = mkOptionType {
  name = "port";
  check = x: isInt x && x >= 1 && x <= 65535;
  description = "A valid TCP/UDP port number (1-65535)";
};

# IPv4 Address Contract: "x.y.z.w" with octets 0-255
ipv4 = mkOptionType {
  name = "ipv4";
  check = s: isString s && validateIpv4 s;
  description = "An IPv4 address in dotted-decimal format";
};

# CIDR Subnet Contract: "x.y.z.w/prefix"
cidr = mkOptionType {
  name = "cidr";
  check = s: isString s && validateCidr s;
  description = "An IPv4 CIDR prefix notation";
};

# Byte Size Contract: "512MB", "4GB", "10TB"
byteSize = mkOptionType {
  name = "byteSize";
  check = s: isString s && validateByteSize s;
  description = "Human-readable byte size with standard binary prefix";
};

# NIST Cryptographic Hash Contract: 64-character lowercase hex string
sha256 = mkOptionType {
  name = "sha256";
  check = s: isString s && stringLength s == 64 && isHex s;
  description = "A 64-character lowercase SHA-256 hexadecimal digest";
};
```

---

## 4. Architectural Invariant Assertion Engine

Praxis allows modules to register invariant assertions through `config.assertions`. Assertions are evaluated after the configuration fixed-point reaches equilibrium:

```nix
assertions = [
  {
    assertion = config.cluster.raft.quorumSize >= 3;
    message = "Raft consensus requires a minimum quorum size of 3 nodes to tolerate partitions.";
  }
  {
    assertion = config.microvm.vcpu.count <= config.host.physicalCores;
    message = "MicroVM vCPU count cannot exceed physical host core capacity without overcommit enabled.";
  }
  {
    assertion = config.network.wireguard.listenPort != config.services.ingress.httpPort;
    message = "WireGuard listen port conflicts with ingress reverse proxy port.";
  }
];
```

If any assertion condition evaluates to `false`, the evaluator terminates with a descriptive diagnostic message indicating the violated invariant, preventing misconfigured infrastructures from ever generating deployment artifacts.
