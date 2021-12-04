// Praxis Execution Engine Tests: Parser

use praxis_core::nix_ast::{parse_nix, BinaryOp, Expr, Literal, Pattern};

#[test]
fn test_parse_literals() {
    let expr = parse_nix("42").expect("Parse failed");
    assert_eq!(expr, Expr::Lit(Literal::Int(42)));

    let expr = parse_nix(r#""praxis""#).expect("Parse failed");
    assert_eq!(expr, Expr::Lit(Literal::Str("praxis".to_string())));

    let expr = parse_nix("true").expect("Parse failed");
    assert_eq!(expr, Expr::Lit(Literal::Bool(true)));
}

#[test]
fn test_parse_binary_precedence() {
    let expr = parse_nix("1 + 2 * 3").expect("Parse failed");
    // Should parse as 1 + (2 * 3)
    if let Expr::BinOp { op, left, right } = expr {
        assert_eq!(op, BinaryOp::Add);
        assert_eq!(*left, Expr::Lit(Literal::Int(1)));
        if let Expr::BinOp { op: r_op, .. } = *right {
            assert_eq!(r_op, BinaryOp::Mul);
        } else {
            panic!("Expected multiplication on right");
        }
    } else {
        panic!("Expected binary addition");
    }
}

#[test]
fn test_parse_lambda() {
    let expr = parse_nix("x: x + 1").expect("Parse failed");
    if let Expr::Lambda { pattern, .. } = expr {
        assert_eq!(pattern, Pattern::Simple("x".to_string()));
    } else {
        panic!("Expected lambda expression");
    }
}

#[test]
fn test_parse_attribute_set() {
    let expr = parse_nix("{ a = 1; b = 2; }").expect("Parse failed");
    if let Expr::AttrSet { is_rec, entries } = expr {
        assert!(!is_rec);
        assert_eq!(entries.len(), 2);
    } else {
        panic!("Expected attribute set");
    }
}
