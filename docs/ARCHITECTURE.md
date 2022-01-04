# Praxis System Architecture

Praxis is a declarative cloud operating fabric and zero-trust infrastructure hypervisor implemented in pure Nix, complemented by a high-performance Rust execution engine and discrete event simulator.

Praxis unifies microVM virtualization, kernel-level eBPF packet routing, WireGuard mesh networking, distributed consensus, relational database migrations, and software supply chain provenance into a single hermetic, mathematically sound evaluation model.

```
+========================================================================================+
|                                    PRAXIS ECOSYSTEM                                    |
+========================================================================================+
|                                                                                        |
|  +----------------------------------------------------------------------------------+  |
|  |                             DECLARATIVE SPECIFICATION                            |  |
|  |   - System Hardening     - MicroVM Hypervisors    - WireGuard Cryptographic Mesh |  |
|  |   - OCI Image Manifests  - Relational Schemas     - eBPF XDP Packet Filtering    |  |
|  |   - Cluster Raft Quorums - SLSA Provenance v1.0   - CycloneDX 1.5 SBOM Manifests |  |
|  +-----------------------------------------+----------------------------------------+  |
|                                            |                                           |
|                                            v                                           |
|  +----------------------------------------------------------------------------------+  |
|  |                        PRAXIS PURE NIX STANDARD LIBRARY                          |  |
|  |   - Lazy Semi-Lattice Option Merging     - Okasaki Red-Black Balanced BST        |  |
|  |   - Radix Trie (LPM IP Routing)          - Leftist Priority Queues (Min/Max Heap)|  |
|  |   - Tarjan Strongly Connected Components - Kahn Topological Sort (Cycle Analysis)|  |
|  |   - Dijkstra / Bellman-Ford Shortest Path- Lengauer-Tarjan Dominator Trees       |  |
|  |   - NIST FIPS 180-4 SHA-256 Digest Engine- RFC 2104 HMAC-SHA256 Authenticator    |  |
|  |   - RFC 4648 Base64 / Hex Serializers    - RFC 4122 UUIDv4/v5 Generators         |  |
|  +-----------------------------------------+----------------------------------------+  |
|                                            |                                           |
|                                            v                                           |
|  +----------------------------------------------------------------------------------+  |
|  |                           HIGH-PERFORMANCE RUST ENGINE                           |  |
|  |   - Lazy Thunk Evaluator with Graph Memoization and Scope Chaining               |  |
|  |   - AST Schema Validator and Static Linter                                       |  |
|  |   - Discrete Event Firecracker MicroVM Boot Simulator                            |  |
|  |   - 5-Node Raft Consensus Network with Split-Brain Partition Injector            |  |
|  |   - Wing and Gong Linearizability Verifier                                       |  |
|  |   - Artifact Compilers (OCI v1.1, Systemd Units, eBPF C Kernels, SLSA v1.0)      |  |
|  +-----------------------------------------+----------------------------------------+  |
|                                            |                                           |
|                                            v                                           |
|  +----------------------------------------------------------------------------------+  |
|  |                           TARGET RUNTIME DEPLOYMENTS                             |  |
|  |   [ Firecracker MicroVMs ]   [ eBPF XDP Offload ]   [ WireGuard Secure Mesh ]    |  |
|  |   [ OCI Image Registries ]   [ Systemd Supervised ] [ Terraform / K8s Manifests] |  |
|  +----------------------------------------------------------------------------------+  |
+========================================================================================+
```

---

## 1. Core Architectural Pillars

### 1.1 Pure Functional Foundations
In traditional infrastructure-as-code tooling, side effects, implicit state mutation, and non-deterministic environment discovery cause configuration drift. Praxis eliminates drift by formulating all infrastructure configurations as pure mathematical expressions in Nix.
- **Hermetic Evaluation**: Configurations evaluate strictly to immutable abstract syntax trees without touching network sockets or ambient disk state.
- **Algebraic Option Resolution**: Configuration options form a bounded join-semilattice. Multiple definitions merge monotonically according to explicit priority tiers (`mkForce`, `mkDefault`, `mkOverride`).
- **Sound Structural Typing**: Every module parameter is guarded by structural contracts validating boundaries, ports, IP formats, storage capacities, and cryptographically valid hashes.

### 1.2 Multi-Stage Lifecycle Pipeline

The lifecycle of a Praxis infrastructure definition transitions through five strictly ordered phases:

```
+----------------+      +------------------+      +-----------------+
| Specification  | ---> | Fixed-Point Eval | ---> | Static Linter   |
| (Nix Modules)  |      | (Semi-Lattice)   |      | (AST Validation)|
+----------------+      +------------------+      +-----------------+
                                                           |
                                                           v
+----------------+      +------------------+      +-----------------+
| Runtime Deploy | <--- | Simulation Suite | <--- | Artifact Synth  |
| (MicroVM/eBPF) |      | (Raft/Linearize) |      | (OCI/Systemd/C) |
+----------------+      +------------------+      +-----------------+
```

1. **Specification**: Developers declare systems using modular, composable Nix records. Modules declare configuration options, defaults, and assertions.
2. **Fixed-Point Evaluation**: The lazy module engine computes the fixed-point closure of all imports, verifying that all invariants hold and resolving conflicts deterministically.
3. **Static Linting & Verification**: The Praxis engine parses the syntax tree, inspecting variable bindings, checking for unreachable nodes, dead code, and unresolved symbol references.
4. **Artifact Synthesis**: Specialized generators emit target runtime configurations:
   - Hardened OCI v1.1 Image Manifests and layer blobs.
   - Low-latency eBPF C filters matching exact network firewall policies.
   - Hardened systemd execution units with restricted capabilities and namespace isolation.
   - Cryptographic SLSA Level 4 provenance statements with CycloneDX 1.5 SBOM metadata.
5. **Simulation & Linearizability Testing**: Before deployment, the cluster simulation engine boots the topology inside an in-memory discrete event loop. Raft election transitions, network partitions, and microVM boot stages are executed and verified against strict linearizability specifications.

---

## 2. Subsystem Interaction and Topology

```
+---------------------------------------------------------------------------------------+
|                             TOPOLOGY AND DATA FLOW PIPELINE                           |
+---------------------------------------------------------------------------------------+
|                                                                                       |
|   +-------------------+          +--------------------+         +-----------------+   |
|   |  Cluster Topology | -------> | Network Fabric     | ------> | eBPF Kernel Gen |   |
|   |  (Multi-Region)   |          | (WireGuard Overlay)|         | (XDP / TC Filter|   |
|   +-------------------+          +--------------------+         +-----------------+   |
|             |                              |                                          |
|             v                              v                                          |
|   +-------------------+          +--------------------+         +-----------------+   |
|   |  Consensus Engine |          | MicroVM Sandbox    | ------> | Rootfs Storage  |   |
|   |  (Raft Quorum)    |          | (Firecracker/CH)   |         | (LUKS2 / dm-ver)|   |
|   +-------------------+          +--------------------+         +-----------------+   |
|             |                              |                                          |
|             v                              v                                          |
|   +-------------------+          +--------------------+         +-----------------+   |
|   |  Relational DB    |          | Supply Chain Attest| ------> | Target Artifacts|   |
|   |  (Migration Diff) |          | (SLSA L4 / SBOM)   |         | (OCI / Systemd) |   |
|   +-------------------+          +--------------------+         +-----------------+   |
|                                                                                       |
+---------------------------------------------------------------------------------------+
```

### 2.1 MicroVM Hardware Virtualization Subsystem
The `modules/microvm` module models microVM workloads targeted for Firecracker and Cloud-Hypervisor. It models kernel parameter passing, initramfs pivot_root scripts, virtual CPU topologies with physical core affinity, hugepage memory backing, virtio block/net devices, and jailer chroot confinement.

### 2.2 Network Fabric & eBPF Filtering
The `modules/network` module manages the complete software-defined network stack:
- **WireGuard Full-Mesh**: Fully cryptographic point-to-point peering with pre-shared keys, deterministic listen ports, and keepalive intervals.
- **eBPF XDP Offload**: Ingests high-level declarative firewall rules and automatically synthesizes performant eBPF C kernels executing at the network driver layer.
- **mTLS PKI Hierarchy**: Generates certificate authority hierarchies with intermediate issuing nodes, deterministic serial numbers, and cryptographic san-extensions.

### 2.3 Distributed Cluster & Raft Consensus
The `modules/cluster` module orchestrates multi-region node topologies. It specifies quorum parameters, heartbeat ticks, election timeouts, snapshot intervals, and peer addresses. The Rust simulator models network partition injection, candidate elections, log replication, and verifies execution histories using the Wing and Gong algorithm.

### 2.4 Database Schema Migrations
The `modules/database` module defines relational database schemas as Nix data structures. The engine features an AST diffing engine that compares current and desired schemas, computing non-destructive, zero-downtime SQL migration paths with transactional table rewrites.

### 2.5 Provenance & Software Supply Chain
The `modules/provenance` module generates SLSA (Supply-chain Levels for Software Artifacts) Level 4 in-toto attestation statements, builds CycloneDX 1.5 JSON SBOM records for all compiled binaries and libraries, and performs CVE vulnerability scanning against NIST databases.

---

## 3. Directory Layout and Repository Structure

The Praxis repository is structured into isolated, cohesive subsystems:

```
praxis/
├── flake.nix                # Flake entrypoint and hermetic package derivation
├── default.nix              # Standard derivation fallback entrypoint
├── shell.nix                # Hermetic developer shell environment
├── lib/                     # Pure Nix standard library and functional algorithms
│   ├── functional.nix       # Combinators, optics, catamorphisms
│   ├── types.nix            # Structural type system and contract validators
│   ├── modules.nix          # Semi-lattice module evaluation and option merging
│   ├── assertions.nix       # Architectural invariant assertion engine
│   ├── rbtree.nix           # Okasaki Red-Black balanced binary search tree
│   ├── trie.nix             # Radix Trie for longest-prefix match routing
│   ├── heap.nix             # Leftist priority queue (min/max heap)
│   ├── disjoint_set.nix     # Disjoint-Set union-find with path compression
│   ├── bitset.nix           # 32-bit bitwise logic using 4-bit nibble tables
│   ├── tarjan.nix           # Tarjan's Strongly Connected Components algorithm
│   ├── toposort.nix         # Kahn's topological sort with cycle diagnostics
│   ├── shortest_path.nix    # Dijkstra and Bellman-Ford shortest path routing
│   ├── dominator.nix        # Lengauer-Tarjan flow graph dominator tree
│   ├── transitive.nix       # Transitive reduction and closure over DAGs
│   ├── sha256.nix           # Pure Nix NIST FIPS 180-4 SHA-256 hash function
│   ├── hmac.nix             # Pure Nix RFC 2104 HMAC-SHA256 authenticator
│   ├── base64.nix           # RFC 4648 Base64 encoder and decoder
│   ├── hex.nix              # Hexadecimal encoder and decoder
│   ├── uuid.nix             # RFC 4122 UUIDv4 and UUIDv5 generators
│   ├── semver.nix           # Semantic Versioning 2.0 parser and solver
│   ├── json.nix             # Deterministic JSON serializer with sorted keys
│   ├── yaml.nix             # Indentation-aware YAML serializer
│   ├── toml.nix             # TOML v1.0 serializer with nested sectioning
│   ├── systemd.nix          # Hardened systemd unit configuration generator
│   ├── shell_gen.nix        # Hardened POSIX/Bash init script generator
│   └── cgroup.nix           # Cgroup v2 controller configuration generator
├── modules/                 # Declarative infrastructure module system
│   ├── system/              # Kernel, bootloader, initramfs, storage, seccomp
│   ├── microvm/             # Firecracker, Cloud-Hypervisor, jailer, virtio
│   ├── oci/                 # OCI Image Spec v1.1, layers, whiteouts, runtime
│   ├── network/             # WireGuard mesh, eBPF XDP, mTLS PKI, DNS, routing
│   ├── cluster/             # Multi-region topology, Raft consensus, supervisor
│   ├── database/            # Relational schema AST diffing and SQL migrations
│   ├── provenance/          # SLSA Level 4 provenance, CycloneDX SBOM, CVE scanner
│   └── cloud/               # Terraform HCL2, CloudFormation, Kubernetes
├── topologies/              # Production workload blueprints
│   ├── hft_colocation.nix   # Ultra-low latency financial trading colocation
│   ├── sovereign_cloud.nix  # 3-region sovereign cloud with Raft consensus
│   └── secure_enclave.nix   # Air-gapped confidential computing microVM
├── engine/                  # High-performance Rust execution engine
│   ├── Cargo.toml           # Engine manifest (zero third-party dependencies)
│   ├── src/                 # Engine source modules
│   │   ├── nix_ast/         # Lexer, recursive descent parser, AST nodes
│   │   ├── evaluator/       # Lazy evaluation, thunk caching, curried builtins
│   │   ├── validator/       # AST static linter and contract checker
│   │   ├── simulator/       # MicroVM boot, eBPF routing, Raft simulator
│   │   ├── generators/      # OCI, systemd, eBPF C kernels, SLSA statements
│   │   └── ui/              # Terminal graph layout and real-time dashboard
│   └── tests/               # Unit and integration test suites
├── tests/                   # Unified test suites
│   ├── nix/                 # 24 pure Nix verification test suites
│   └── test_harness.py      # Automated Python multi-tier test harness
├── scripts/                 # Utility scripts and invariant checkers
│   └── check_no_em_dashes.py# Zero-tolerance em dash scanner
├── docs/                    # Deep technical architecture documentation
└── test.sh                  # One-click comprehensive test execution script
```
