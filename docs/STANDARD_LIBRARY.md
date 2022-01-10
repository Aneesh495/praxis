# Praxis Pure Nix Standard Library

Praxis implements an extensive, self-contained standard library in pure Nix (`lib/`). It provides functional combinators, advanced purely functional data structures, graph traversal algorithms, cryptographic hashing engines, and deterministic configuration format serializers.

```
+========================================================================================+
|                              PRAXIS STANDARD LIBRARY MODULES                           |
+========================================================================================+
|                                                                                        |
|   +-----------------------+   +-----------------------+   +------------------------+   |
|   | Functional Primitives |   | Immutable Structures  |   | Graph Theory Suite     |   |
|   |  - Lens Optics        |   |  - Okasaki RB-Tree    |   |  - Tarjan SCC Search   |   |
|   |  - Catamorphic Folds  |   |  - Radix Trie (LPM)   |   |  - Kahn Toposort       |   |
|   |  - Y-Combinator       |   |  - Leftist Heap       |   |  - Dijkstra Routing    |   |
|   |  - Monadic Pipelines  |   |  - Disjoint-Set Union |   |  - Lengauer-Tarjan Dom |   |
|   +-----------------------+   +-----------------------+   +------------------------+   |
|                                                                                        |
|   +-----------------------+   +-----------------------+   +------------------------+   |
|   | Cryptographic Engines |   | Serializers & Formats |   | System Generators      |   |
|   |  - FIPS 180-4 SHA-256 |   |  - Sorted Key JSON    |   |  - Hardened Systemd    |   |
|   |  - RFC 2104 HMAC-256  |   |  - Indentation YAML   |   |  - Cgroup v2 Hierarchy |   |
|   |  - RFC 4648 Base64    |   |  - TOML v1.0 Tables   |   |  - Initramfs Scripts   |   |
|   |  - RFC 4122 UUIDv4/v5 |   |  - SemVer 2.0 Parser  |   |  - POSIX Shell Emitter |   |
|   +-----------------------+   +-----------------------+   +------------------------+   |
+========================================================================================+
```

---

## 1. Pure Functional Data Structures

### 1.1 Okasaki Red-Black Balanced Binary Search Tree (`lib/rbtree.nix`)
The Red-Black tree is an immutable self-balancing binary search tree based on Chris Okasaki's classic functional balance formulation (*Purely Functional Data Structures*, Cambridge University Press).

- **Invariants Maintained**:
  1. Every node is either `Red` or `Black`.
  2. The root node is always `Black`.
  3. No red node has a red child (Red property).
  4. Every path from the root to any leaf contains the exact same number of black nodes (Black height property).
- **Okasaki Balance Formulation**: Rebalancing folds four distinct rotation configurations into a single canonical functional pattern matching rule:

```nix
balance = color: left: key: value: right:
  if color == "Black" then
    # Case 1: Left-Left red violation
    if isRed left && isRed left.left then
      mkNode "Red" (mkNode "Black" left.left.left left.left.key left.left.value left.left.right)
                   left.key left.value
                   (mkNode "Black" left.right key value right)
    # Case 2: Left-Right red violation
    else if isRed left && isRed left.right then
      mkNode "Red" (mkNode "Black" left.left left.key left.value left.right.left)
                   left.right.key left.right.value
                   (mkNode "Black" left.right.right key value right)
    # Case 3: Right-Left red violation
    else if isRed right && isRed right.left then
      mkNode "Red" (mkNode "Black" left key value right.left.left)
                   right.left.key right.left.value
                   (mkNode "Black" right.left.right right.key right.value right.right)
    # Case 4: Right-Right red violation
    else if isRed right && isRed right.right then
      mkNode "Red" (mkNode "Black" left key value right.left)
                   right.key right.value
                   (mkNode "Black" right.right.left right.right.key right.right.value right.right.right)
    else
      mkNode color left key value right
  else
    mkNode color left key value right;
```

### 1.2 Radix Trie for Longest-Prefix Match Routing (`lib/trie.nix`)
The Radix Trie provides $O(k)$ prefix-based key search, where $k$ is key length. It powers:
- Longest-prefix match (LPM) packet routing in network router definitions.
- Hierarchical namespace and permission path resolution.
- Key compression across sparse routing tables.

### 1.3 Leftist Priority Queue (`lib/heap.nix`)
Leftist heaps are purely functional priority queues satisfying the leftist property: the rank (distance to the nearest external node) of any left child is at least as large as the rank of its right sibling.
- **Merge Operation**: Runs in $O(\log n)$ by recursively merging along the right spine and swapping children if the leftist property is violated.
- **Operations**: `insert`, `findMin`, `deleteMin`, `fromList`.

### 1.4 Disjoint-Set Union-Find (`lib/disjoint_set.nix`)
An immutable Disjoint-Set forest with path compression and rank heuristics.
- Powers cluster network partition simulations, connected component analysis, and Kruskal minimum spanning tree synthesizers.

---

## 2. Advanced Graph Theory Algorithms

### 2.1 Tarjan's Strongly Connected Components (`lib/tarjan.nix`)
Tarjan's algorithm traverses directed dependency graphs in $O(V + E)$ time using depth-first search, discovering strongly connected components via depth indexes and low-link numbers:
- Used in module dependency analysis to detect mutually recursive cycles and isolate independent sub-clusters.

### 2.2 Kahn's Topological Sort (`lib/toposort.nix`)
Kahn's algorithm produces a linear ordering of vertices in a directed acyclic graph (DAG):
- Evaluates in-degree counts across all nodes.
- Extracts parallel scheduling tiers: tasks that share no mutual dependencies can execute concurrently in parallel worker queues.
- Detects remaining dependency cycles and outputs human-readable diagnostic traces.

### 2.3 Shortest Path Routing (`lib/shortest_path.nix`)
- **Dijkstra's Algorithm**: Calculates minimum latency routing paths across positive-weighted networks using priority queues.
- **Bellman-Ford Algorithm**: Handles arbitrary edge weights and detects negative weight cycles in cost optimization matrices.

### 2.4 Lengauer-Tarjan Dominator Tree Analysis (`lib/dominator.nix`)
Computes the dominator tree of a directed control or data flow graph:
- A node $d$ dominates $n$ if every path from the entry node to $n$ must pass through $d$.
- Identifies single points of failure (chokepoints) in high-availability cluster networks and microVM service topologies.

---

## 3. Cryptographic Primitives in Pure Nix

### 3.1 NIST FIPS 180-4 SHA-256 Engine (`lib/sha256.nix`)
Praxis implements the complete NIST SHA-256 secure hash algorithm directly in pure Nix, without invoking external binary helpers or derivations:
- **32-bit Logic via Truth Tables (`lib/bitset.nix`)**: Because Nix represents numbers as signed 64-bit integers and lacks native bitwise shift/rotate primitives, Praxis precomputes 4-bit nibble truth tables for bitwise AND, OR, and XOR. Right rotations (`rotr32`) and logical shifts (`shr32`) are performed via arithmetic modulo operations.
- **Message Schedule Expansion**: Expands 16 32-bit input words into 64 words using SHA-256 mixing functions $\sigma_0$ and $\sigma_1$.
- **Compression Loop**: Iterates through 64 rounds with round constants $K_t$, updating hash working variables $a$ through $h$.
- **Validation**: Meticulously verified against official NIST CAVP test vectors (including empty string, single block, and multi-block inputs).

### 3.2 RFC 2104 HMAC-SHA256 Message Authentication (`lib/hmac.nix`)
Computes cryptographic Hash-based Message Authentication Codes:

$$\text{HMAC}(K, m) = H((K' \oplus \text{opad}) \parallel H((K' \oplus \text{ipad}) \parallel m))$$

- Handles key padding/hashing when key length exceeds the 64-byte block size.
- Prepares authenticated tokens for internal service communication and WireGuard pre-shared key validation.

---

## 4. Codecs and Deterministic Serializers

| Module | Standard | Capabilities |
| :--- | :--- | :--- |
| `lib/base64.nix` | RFC 4648 | Standard and URL-safe Base64 encoding and decoding |
| `lib/hex.nix` | Hexadecimal | Low-level byte and nibble conversion with zero-padding |
| `lib/uuid.nix` | RFC 4122 | Cryptographically formatted UUIDv4 (random) and UUIDv5 (SHA-1/name) |
| `lib/semver.nix` | SemVer 2.0 | Major.Minor.Patch parsing, prerelease tags, caret (`^`) and tilde (`~`) constraints |
| `lib/json.nix` | RFC 8259 | Strictly sorted keys for reproducible bit-for-bit identical outputs |
| `lib/yaml.nix` | YAML 1.2 | Indentation-sensitive block formatting with multiline string wrapping |
| `lib/toml.nix` | TOML v1.0 | Key-value pairs, nested tables, inline arrays, and escaped strings |
| `lib/systemd.nix` | Systemd Spec | Generates hardened unit files with namespace and capability sandboxing |
| `lib/cgroup.nix` | Cgroups v2 | Memory, CPU, and I/O controller configuration hierarchies |
| `lib/shell_gen.nix` | POSIX / Bash | Defensive shell scripts with `set -euo pipefail` and safe quoting |
