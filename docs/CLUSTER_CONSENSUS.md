# Praxis Distributed Consensus and Cluster Simulation

Praxis provides a declarative cluster consensus specification (`modules/cluster/`) integrated with a discrete-event Raft consensus engine and linearizability verification suite implemented in the Rust runtime (`engine/src/simulator/`).

```
+========================================================================================+
|                              5-NODE RAFT CONSENSUS NETWORK                             |
+========================================================================================+
|                                                                                        |
|         +-------------------+         +-------------------+                            |
|         | Node 1 (Leader)   | <-----> | Node 2 (Follower) |                            |
|         | Term: 2, Log: 42  |         | Term: 2, Log: 42  |                            |
|         +---------+---------+         +---------+---------+                            |
|                   |                             |                                      |
|                   |      MAJORITY QUORUM (3)    |                                      |
|                   v                             v                                      |
|         +-------------------+         +-------------------+                            |
|         | Node 3 (Follower) |         |  NETWORK SPLIT    |  <-- Split-Brain Partition |
|         | Term: 2, Log: 42  |         +-------------------+      Fault Injection       |
|         +-------------------+                   |                                      |
|                                                 v                                      |
|                                       +-------------------+                            |
|                                       | Node 4 (Follower) |                            |
|                                       | Term: 1, Log: 38  |                            |
|                                       +---------+---------+                            |
|                                                 |                                      |
|                                                 v                                      |
|                                       +-------------------+                            |
|                                       | Node 5 (Follower) |                            |
|                                       | Term: 1, Log: 38  |                            |
|                                       +-------------------+                            |
|                                        MINORITY QUORUM (2)                             |
|                                       (HALTS COMMITMENTS)                              |
+========================================================================================+
```

---

## 1. Raft Consensus Protocol Implementation

The Praxis cluster simulator models the full Raft state machine specification (Ongaro and Ousterhout):

### 1.1 State Transitions
Every node in the cluster exists in one of three states:
- **Follower**: Responds to incoming Remote Procedure Calls (RPCs) from candidates and leaders. If election timeout elapses without receiving heartbeats, the node increments its term and transitions to Candidate.
- **Candidate**: Broadcasts `RequestVote` RPCs to all peers. If it secures votes from a strict majority ($> N/2$), it transitions to Leader. If an append RPC from a valid leader with an equal or higher term is received, it reverts to Follower.
- **Leader**: Manages log replication, issues periodic `AppendEntries` heartbeats, updates the commit index upon majority acknowledgment, and applies committed entries to the local state machine.

### 1.2 Quorum Invariant Enforcement
To prevent conflicting split-brain updates during network partitions, the consensus engine enforces the fundamental quorum intersection property:

$$Q_1 \cap Q_2 \neq \emptyset \quad \forall Q_1, Q_2 \subseteq \mathcal{N} \quad \text{where} \quad |Q_i| > \frac{|\mathcal{N}|}{2}$$

Any two majorities must share at least one node, guaranteeing that at most one valid leader can exist per term.

---

## 2. Discrete Event Simulation and Fault Injection

The Praxis engine features an in-memory discrete event simulator (`engine/src/simulator/raft.rs`) that executes complex failure topologies without requiring physical VM provisioning:

```rust
// Initialize 5-node cluster
let mut cluster = RaftCluster::new(5);

// Step 1: Run election round to establish stable leader
cluster.tick(10);
let leader = cluster.find_leader().expect("Cluster must elect a leader");

// Step 2: Inject network split-brain partition
// Partition A: [1, 2, 3] (Majority Quorum)
// Partition B: [4, 5]    (Minority Quorum)
cluster.inject_network_partition(vec![1, 2, 3], vec![4, 5]);

// Step 3: Issue write proposal to Node 1 (Majority)
assert!(cluster.propose_entry(1, "config_update_v2"));

// Step 4: Issue write proposal to Node 4 (Minority)
// Minority cannot reach consensus and rejects or stalls the proposal
assert!(!cluster.propose_entry(4, "conflicting_update"));

// Step 5: Heal partition and verify log convergence
cluster.heal_network_partition();
cluster.tick(20);
assert!(cluster.verify_log_consistency());
```

---

## 3. Wing and Gong Linearizability Verification

To verify that concurrent read/write executions produce valid sequential histories, Praxis implements the classic Wing and Gong linearizability verification algorithm (`engine/src/simulator/linearizability.rs`).

### 3.1 Linearizability Definition
A concurrent execution trace is **linearizable** if there exists a valid sequential order $S$ of all operations such that:
1. $S$ matches the sequential specification of the object (e.g. read returns the most recently written value).
2. For any two operations $op_1$ and $op_2$, if $op_1$ completed before $op_2$ began in physical time ($op_1.\text{end} < op_2.\text{start}$), then $op_1$ precedes $op_2$ in $S$.

### 3.2 Verification Algorithm
The Wing and Gong verifier searches for a valid topological linearization by traversing the execution history:
- Identifies minimal unlinearized operations whose start times do not exceed the current logical timestamp.
- Applies candidate operations against an in-memory sequential model.
- Recursively backtracks if an operation violates sequential semantics (e.g., stale reads), pruning impossible histories until a valid linearization is found or all branches fail.

```
Concurrent Execution Timeline:
Thread A: |--- Write("k", "v1") ---|
Thread B:          |--- Read("k") -> "v1" ---|
Thread C:                       |--- Write("k", "v2") ---|
Thread D:                                    |--- Read("k") -> "v2" ---|

Linearization Proof:
  Step 1: Write("k", "v1") [Valid]
  Step 2: Read("k") -> "v1" [Valid: matches last write]
  Step 3: Write("k", "v2") [Valid]
  Step 4: Read("k") -> "v2" [Valid: matches last write]
Linearizability Result: PASSED (Verified across 100% of generated states)
```

---

## 4. Systemd Supervisor Directed Acyclic Graph

Praxis compiles cluster service dependencies into a unified supervisor DAG (`modules/cluster/supervisor.nix`):
- Models unit dependencies with `Requires`, `Wants`, `After`, and `Before` attributes.
- Leverages Kahn's topological sort from the standard library to guarantee acyclic execution.
- Emits fully hardened systemd units with restricted namespaces, memory quotas, and automatic restart backoff schedules.
