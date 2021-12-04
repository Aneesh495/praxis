// Praxis Execution Engine Tests: Linearizability Verifier

use praxis_core::simulator::{LinearizabilityVerifier, OpType, Operation};

#[test]
fn test_valid_sequential_history() {
    let verifier = LinearizabilityVerifier::new();
    let history = vec![
        Operation {
            client_id: 1,
            op_type: OpType::Put("k1".to_string(), "v1".to_string()),
            invoke_time: 1,
            return_time: 5,
        },
        Operation {
            client_id: 2,
            op_type: OpType::Get("k1".to_string(), "v1".to_string()),
            invoke_time: 6,
            return_time: 10,
        },
    ];
    assert!(verifier.verify(&history));
}

#[test]
fn test_stale_read_violation() {
    let verifier = LinearizabilityVerifier::new();
    let history = vec![
        Operation {
            client_id: 1,
            op_type: OpType::Put("k1".to_string(), "v2".to_string()),
            invoke_time: 1,
            return_time: 5,
        },
        Operation {
            client_id: 2,
            op_type: OpType::Get("k1".to_string(), "v1".to_string()), // Expects v1 but state has v2
            invoke_time: 6,
            return_time: 10,
        },
    ];
    assert!(!verifier.verify(&history));
}
