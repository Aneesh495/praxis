// Praxis Execution Engine Tests: Evaluator

use praxis_core::evaluator::{eval_nix_source, Value};

#[test]
fn test_eval_arithmetic() {
    let res = eval_nix_source("10 + 20 * 3").expect("Eval failed");
    if let Value::Int(n) = res {
        assert_eq!(n, 70);
    } else {
        panic!("Expected integer 70");
    }
}

#[test]
fn test_eval_let_in() {
    let res = eval_nix_source("let x = 5; y = 10; in x * y").expect("Eval failed");
    if let Value::Int(n) = res {
        assert_eq!(n, 50);
    } else {
        panic!("Expected integer 50");
    }
}

#[test]
fn test_eval_higher_order_lambda() {
    let res = eval_nix_source("let f = x: y: x + y; in f 12 30").expect("Eval failed");
    if let Value::Int(n) = res {
        assert_eq!(n, 42);
    } else {
        panic!("Expected integer 42");
    }
}

#[test]
fn test_eval_attrset_update() {
    let res = eval_nix_source("let a = { x = 1; y = 2; }; b = { y = 99; z = 3; }; in a // b")
        .expect("Eval failed");
    if let Value::Attrs(attrs) = res {
        assert_eq!(attrs.len(), 3);
        if let Some(Value::Int(y_val)) = attrs.get("y") {
            assert_eq!(*y_val, 99);
        } else {
            panic!("Expected y = 99 in updated attrset");
        }
    } else {
        panic!("Expected attribute set");
    }
}

#[test]
fn test_eval_builtins() {
    let res = eval_nix_source(r#"builtins.stringLength "praxis""#).expect("Eval failed");
    if let Value::Int(len) = res {
        assert_eq!(len, 6);
    } else {
        panic!("Expected stringLength 6");
    }

    let res = eval_nix_source(r#"builtins.substring 0 4 "praxis""#).expect("Eval failed");
    if let Value::Str(sub) = res {
        assert_eq!(sub, "prax");
    } else {
        panic!("Expected substring 'prax'");
    }
}
