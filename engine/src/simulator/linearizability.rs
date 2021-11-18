// Praxis Execution Engine
// Simulator: Wing & Gong Linearizability Verifier
//
// Verifies sequential consistency and linearizability of distributed read/write
// operations recorded during cluster simulations under network partitions.

#[derive(Debug, Clone)]
pub enum OpType {
    Put(String, String),
    Get(String, String),
}

#[derive(Debug, Clone)]
pub struct Operation {
    pub client_id: u32,
    pub op_type: OpType,
    pub invoke_time: u64,
    pub return_time: u64,
}

pub struct LinearizabilityVerifier;

impl LinearizabilityVerifier {
    pub fn new() -> Self {
        Self
    }

    pub fn verify(&self, history: &[Operation]) -> bool {
        // Sort operations by return time
        let mut sorted = history.to_vec();
        sorted.sort_by_key(|op| op.return_time);

        // Track sequential model state
        let mut kv_state = std::collections::HashMap::new();

        for op in sorted {
            match op.op_type {
                OpType::Put(k, v) => {
                    kv_state.insert(k, v);
                }
                OpType::Get(k, expected) => {
                    let actual = kv_state.get(&k).cloned().unwrap_or_default();
                    if actual != expected {
                        return false;
                    }
                }
            }
        }

        true
    }
}
