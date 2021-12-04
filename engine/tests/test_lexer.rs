// Praxis Execution Engine Tests: Lexer

use praxis_core::nix_ast::{Lexer, Token};

#[test]
fn test_lex_basic_tokens() {
    let mut lexer = Lexer::new("let a = 42; in a");
    let tokens = lexer.tokenize().expect("Tokenize failed");
    assert_eq!(tokens[0], Token::Let);
    assert_eq!(tokens[1], Token::Ident("a".to_string()));
    assert_eq!(tokens[2], Token::Assign);
    assert_eq!(tokens[3], Token::Int(42));
    assert_eq!(tokens[4], Token::Semicolon);
    assert_eq!(tokens[5], Token::In);
    assert_eq!(tokens[6], Token::Ident("a".to_string()));
    assert_eq!(tokens[7], Token::Eof);
}

#[test]
fn test_lex_string_and_operators() {
    let mut lexer = Lexer::new(r#""hello" // { b = 1; } ++ [ 2 ]"#);
    let tokens = lexer.tokenize().expect("Tokenize failed");
    assert_eq!(tokens[0], Token::Str("hello".to_string()));
    assert_eq!(tokens[1], Token::Update);
    assert_eq!(tokens[2], Token::OpenBrace);
    assert_eq!(tokens[3], Token::Ident("b".to_string()));
    assert_eq!(tokens[4], Token::Assign);
    assert_eq!(tokens[5], Token::Int(1));
    assert_eq!(tokens[6], Token::Semicolon);
    assert_eq!(tokens[7], Token::CloseBrace);
    assert_eq!(tokens[8], Token::Concat);
}

#[test]
fn test_lex_comments() {
    let mut lexer = Lexer::new("# line comment\n42 /* block comment */");
    let tokens = lexer.tokenize().expect("Tokenize failed");
    assert_eq!(tokens[0], Token::Int(42));
    assert_eq!(tokens[1], Token::Eof);
}
