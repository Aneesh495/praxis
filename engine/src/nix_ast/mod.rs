// Praxis Execution Engine
// Nix AST Module: Lexer, Abstract Syntax Tree, and Recursive Descent Parser

pub mod ast;
pub mod lexer;
pub mod parser;

pub use ast::*;
pub use lexer::{Lexer, Token};
pub use parser::Parser;

pub fn parse_nix(source: &str) -> Result<Expr, String> {
    let mut lexer = Lexer::new(source);
    let tokens = lexer.tokenize()?;
    let mut parser = Parser::new(tokens);
    parser.parse_expression()
}
