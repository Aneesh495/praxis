# Praxis Formal Verification and Testing Methodology

Praxis adheres to a zero-defect engineering standard. Every data structure, cryptographic function, module merging rule, distributed state machine, and runtime generator is accompanied by comprehensive verification suites.

```
+========================================================================================+
|                              MULTI-TIER VERIFICATION MATRIX                            |
+========================================================================================+
|                                                                                        |
|   +--------------------------------------------------------------------------------+   |
|   |                   TIER 1: PURE NIX FUNCTIONAL VERIFICATION                     |   |
|   |   - 24 Pure Nix Test Suites (tests/nix/)                                       |   |
|   |   - Invariant Testing: Okasaki RB-Tree, Radix Trie, Leftist Heap, Disjoint-Set |   |
|   |   - Graph Proofs: Tarjan SCC, Kahn Toposort, Dijkstra Shortest Path, Dominator |   |
|   |   - NIST CAVP SHA-256 and RFC 2104 HMAC Test Vectors                           |   |
|   +---------------------------------------+----------------------------------------+   |
|                                           |                                            |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                   TIER 2: RUST ENGINE SYSTEM INTEGRATION                       |   |
|   |   - 17 Rust Core Unit & Integration Tests (engine/tests/)                      |   |
|   |   - Lexer & Recursive Descent Parser Test Harness                              |   |
|   |   - Lazy Thunk Evaluator with Scope Chaining & Memoization                     |   |
|   |   - MicroVM Discrete Event Boot Sequence Emulator                              |   |
|   +---------------------------------------+----------------------------------------+   |
|                                           |                                            |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |               TIER 3: DISTRIBUTED LINEARIZABILITY VERIFICATION                 |   |
|   |   - 5-Node Raft Consensus Network with Split-Brain Fault Injection             |   |
|   |   - Wing and Gong Linearizability Algorithm Implementation                     |   |
|   |   - Verification of Stale Read Rejection and Sequential Consistency Proofs     |   |
|   +---------------------------------------+----------------------------------------+   |
|                                           |                                            |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                 TIER 4: STATIC LINTING AND CODEBASE AUDITING                   |   |
|   |   - Automated Zero-Tolerance Em Dash Scanner (scripts/check_no_em_dashes.py)   |   |
|   |   - Static Nix AST Linter & Unused Variable Checker (praxis lint)              |   |
|   +--------------------------------------------------------------------------------+   |
+========================================================================================+
```

---

## 1. Pure Nix Functional Test Suites (`tests/nix/`)

The pure Nix test framework (`tests/nix/test_runner.nix`) evaluates test cases hermetically without relying on external test frameworks:

| Test Suite | File | Test Cases & Invariants Tested |
| :--- | :--- | :--- |
| **RB-Tree** | `test_rbtree.nix` | Okasaki rebalancing, black-height invariance across all paths, absence of adjacent red nodes, in-order sortedness |
| **Radix Trie** | `test_trie.nix` | Prefix insertion, exact match lookup, longest-prefix match (LPM) IP routing |
| **Leftist Heap** | `test_heap.nix` | Min-heap ordering property, leftist rank property ($rank(L) \ge rank(R)$), heap sort equivalence |
| **Disjoint-Set** | `test_disjoint_set.nix` | Single-element sets, union operations, path compression, connected component counts |
| **Tarjan SCC** | `test_tarjan.nix` | Acyclic graph decomposition, cyclic component isolation, strongly connected component counts |
| **Toposort** | `test_toposort.nix` | Kahn DAG topological sort, parallel execution tier scheduling, cycle diagnostics |
| **Shortest Path**| `test_shortest_path.nix`| Dijkstra minimum weight paths, Bellman-Ford negative edge detection |
| **Dominator Tree**| `test_dominator.nix`| Lengauer-Tarjan flow graph dominators, chokepoint detection |
| **SHA-256** | `test_sha256.nix` | NIST CAVP vectors: empty string, "abc", multi-block inputs |
| **HMAC-SHA256** | `test_hmac.nix` | RFC 2104 test vectors: standard keys, keys exceeding block size (64 bytes) |
| **Codecs** | `test_base64.nix`, `test_hex.nix`, `test_semver.nix` | RFC 4648 encoding/decoding, padding, hex conversions, SemVer caret/tilde constraint solving |
| **Serializers** | `test_json.nix`, `test_yaml.nix`, `test_toml.nix`, `test_systemd.nix` | Sorted key JSON formatting, YAML indentation, TOML sectioning, Systemd unit sandboxing profiles |
| **Specs** | `test_database.nix`, `test_slsa.nix`, `test_sbom.nix`, `test_cve.nix` | AST schema diffs, zero-downtime DDL, SLSA in-toto statements, CycloneDX 1.5 SBOM, CVE vulnerability gate |
| **Regression** | `test_regression.nix` | Bug reproductions and edge cases discovered during system development |

---

## 2. Rust Engine Integration and Simulation Suites

The Rust runtime (`engine/`) includes 17 automated unit and integration tests executing under `cargo test`:

```
running 17 tests
test test_eval_arithmetic ... ok
test test_eval_attrset_update ... ok
test test_eval_let_in ... ok
test test_eval_higher_order_lambda ... ok
test test_eval_builtins ... ok
test test_lex_basic_tokens ... ok
test test_lex_comments ... ok
test test_lex_string_and_operators ... ok
test test_parse_literals ... ok
test test_parse_binary_precedence ... ok
test test_parse_lambda ... ok
test test_parse_attribute_set ... ok
test test_microvm_boot_simulation ... ok
test test_network_packet_filter_simulation ... ok
test test_raft_consensus_partition_and_recovery ... ok
test test_stale_read_violation ... ok
test test_valid_sequential_history ... ok

test result: ok. 17 passed; 0 failed; 0 ignored; finished in 0.00s
```

---

## 3. Wing and Gong Linearizability Proofs

The linearizability verification engine proves that the simulated distributed system never permits an anomalous execution state:
- **Sequential History Verification**: Feeds concurrent traces into the Wing and Gong verifier to prove that every read observes the valid sequentially committed write.
- **Stale Read Detection Test**: Artificially injects a stale read operation into an execution history and confirms that the verifier detects the violation and rejects the trace with an explicit non-linearizable diagnostic error.

---

## 4. One-Click Verification Runner (`./test.sh`)

Praxis includes a unified verification script (`./test.sh`) executing all tiers in sequence:

```bash
$ ./test.sh
[Praxis] Starting comprehensive verification suite...
=================================================================
       PRAXIS COMPREHENSIVE VERIFICATION TEST SUITE              
=================================================================

[PASS] Em Dash Zero-Tolerance Audit        (0.04s) 
[PASS] Praxis Engine Compilation           (4.07s) 
[PASS] Rust Core Test Suite (17 tests)     (1.67s) 
[PASS] Deterministic Cluster Simulator     (0.30s) 
[PASS] Artifact Synthesis (OCI, eBPF, SLSA) (0.00s) 
[PASS] Topology DAG Visualizer             (0.00s) 
[PASS] Control Plane Status Dashboard      (0.00s) 
[PASS] Nix Eval: Inline Arithmetic & Let-In (0.00s) 
[PASS] Nix Eval: Higher-Order Lambda Currying (0.00s) 
[PASS] Nix Eval: Attribute Set Recursive Merging (0.00s) 
[PASS] Nix Eval: Standard Builtins String Length (0.00s) 
[PASS] Nix Eval: Standard Builtins Substring (0.00s) 
[PASS] Static AST Linter (flake.nix)       (0.00s) 

=================================================================
ALL TESTS PASSED SUCCESSFULLY (Total time: 6.11s)
```
