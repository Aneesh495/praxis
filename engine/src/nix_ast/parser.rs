// Praxis Execution Engine
// Nix Parser: Recursive Descent Parser with Operator Precedence for Nix Expressions

use super::ast::*;
use super::lexer::Token;

pub struct Parser {
    tokens: Vec<Token>,
    pos: usize,
}

impl Parser {
    pub fn new(tokens: Vec<Token>) -> Self {
        Self { tokens, pos: 0 }
    }

    fn peek(&self) -> &Token {
        self.tokens.get(self.pos).unwrap_or(&Token::Eof)
    }

    fn advance(&mut self) -> Token {
        let tok = self.peek().clone();
        if self.pos < self.tokens.len() {
            self.pos += 1;
        }
        tok
    }

    fn check(&self, token: &Token) -> bool {
        self.peek() == token
    }

    fn match_token(&mut self, token: &Token) -> bool {
        if self.check(token) {
            self.advance();
            true
        } else {
            false
        }
    }

    fn expect(&mut self, token: &Token) -> Result<(), String> {
        if self.match_token(token) {
            Ok(())
        } else {
            Err(format!("Expected token {:?}, found {:?}", token, self.peek()))
        }
    }

    pub fn parse_expression(&mut self) -> Result<Expr, String> {
        self.parse_let_or_lambda()
    }

    fn parse_let_or_lambda(&mut self) -> Result<Expr, String> {
        // let ... in ...
        if self.match_token(&Token::Let) {
            let mut bindings = Vec::new();
            while !self.check(&Token::In) && !self.check(&Token::Eof) {
                if self.match_token(&Token::Inherit) {
                    let inherited = self.parse_inherit_entries()?;
                    bindings.extend(inherited);
                } else {
                    let entry = self.parse_attr_entry()?;
                    bindings.push(entry);
                }
            }
            self.expect(&Token::In)?;
            let body = self.parse_expression()?;
            return Ok(Expr::LetIn {
                bindings,
                body: Box::new(body),
            });
        }

        // if ... then ... else ...
        if self.match_token(&Token::If) {
            let cond = self.parse_expression()?;
            self.expect(&Token::Then)?;
            let then_branch = self.parse_expression()?;
            self.expect(&Token::Else)?;
            let else_branch = self.parse_expression()?;
            return Ok(Expr::IfThenElse {
                cond: Box::new(cond),
                then_branch: Box::new(then_branch),
                else_branch: Box::new(else_branch),
            });
        }

        // with ... ; ...
        if self.match_token(&Token::With) {
            let env = self.parse_expression()?;
            self.expect(&Token::Semicolon)?;
            let body = self.parse_expression()?;
            return Ok(Expr::With {
                env: Box::new(env),
                body: Box::new(body),
            });
        }

        // assert ... ; ...
        if self.match_token(&Token::Assert) {
            let cond = self.parse_expression()?;
            self.expect(&Token::Semicolon)?;
            let body = self.parse_expression()?;
            return Ok(Expr::Assert {
                cond: Box::new(cond),
                body: Box::new(body),
            });
        }

        // Lambda parameter check: e.g. "x:" or "{ a, b }:"
        if let Some(pattern) = self.try_parse_lambda_pattern()? {
            self.expect(&Token::Colon)?;
            let body = self.parse_expression()?;
            return Ok(Expr::Lambda {
                pattern,
                body: Box::new(body),
            });
        }

        self.parse_binary(0)
    }

    fn try_parse_lambda_pattern(&mut self) -> Result<Option<Pattern>, String> {
        // Simple identifier followed by colon: "x:"
        if let Token::Ident(name) = self.peek() {
            if self.tokens.get(self.pos + 1) == Some(&Token::Colon) {
                let id = name.clone();
                self.advance(); // consume ident
                return Ok(Some(Pattern::Simple(id)));
            }
        }

        // Formals pattern: "{ a, b ? default, ... }:"
        if self.check(&Token::OpenBrace) {
            // Lookahead to check if this is an attrset or formals pattern
            // A formals pattern typically has commas or '?' or '...' before matching closing brace followed by colon
            let mut depth = 0;
            let mut idx = self.pos;
            let mut is_formals = false;

            while idx < self.tokens.len() {
                match &self.tokens[idx] {
                    Token::OpenBrace => depth += 1,
                    Token::CloseBrace => {
                        depth -= 1;
                        if depth == 0 {
                            if self.tokens.get(idx + 1) == Some(&Token::Colon)
                                || self.tokens.get(idx + 1) == Some(&Token::At)
                            {
                                is_formals = true;
                            }
                            break;
                        }
                    }
                    _ => {}
                }
                idx += 1;
            }

            if is_formals {
                self.advance(); // consume '{'
                let mut args = Vec::new();
                let mut ellipsis = false;

                while !self.check(&Token::CloseBrace) && !self.check(&Token::Eof) {
                    if let Token::Ident(arg_name) = self.peek().clone() {
                        self.advance();
                        let default_val = if self.match_token(&Token::Question) {
                            Some(self.parse_expression()?)
                        } else {
                            None
                        };
                        args.push((arg_name, default_val));
                        self.match_token(&Token::Comma);
                    } else if self.match_token(&Token::Dot) {
                        // ... ellipsis
                        self.match_token(&Token::Dot);
                        self.match_token(&Token::Dot);
                        ellipsis = true;
                        self.match_token(&Token::Comma);
                    } else {
                        break;
                    }
                }
                self.expect(&Token::CloseBrace)?;

                let mut binding = None;
                if self.match_token(&Token::At) {
                    if let Token::Ident(bind_name) = self.advance() {
                        binding = Some(bind_name);
                    }
                }

                return Ok(Some(Pattern::Formals {
                    args,
                    ellipsis,
                    binding,
                }));
            }
        }

        Ok(None)
    }

    fn parse_binary(&mut self, min_prec: u8) -> Result<Expr, String> {
        let mut left = self.parse_unary()?;

        loop {
            let (op, prec, is_right) = match self.peek() {
                Token::Implies => (BinaryOp::Implies, 1, true),
                Token::Or => (BinaryOp::Or, 2, false),
                Token::And => (BinaryOp::And, 3, false),
                Token::Equal => (BinaryOp::Equal, 4, false),
                Token::NotEqual => (BinaryOp::NotEqual, 4, false),
                Token::Less => (BinaryOp::Less, 5, false),
                Token::LessEqual => (BinaryOp::LessEqual, 5, false),
                Token::Greater => (BinaryOp::Greater, 5, false),
                Token::GreaterEqual => (BinaryOp::GreaterEqual, 5, false),
                Token::Update => (BinaryOp::Update, 6, false),
                Token::Plus => (BinaryOp::Add, 8, false),
                Token::Minus => (BinaryOp::Sub, 8, false),
                Token::Multiply => (BinaryOp::Mul, 9, false),
                Token::Divide => (BinaryOp::Div, 9, false),
                Token::Concat => (BinaryOp::Concat, 10, false),
                Token::Question => (BinaryOp::HasAttr, 11, false),
                _ => break,
            };

            if prec < min_prec {
                break;
            }

            self.advance(); // consume operator
            let next_prec = if is_right { prec } else { prec + 1 };
            let right = self.parse_binary(next_prec)?;
            left = Expr::BinOp {
                op,
                left: Box::new(left),
                right: Box::new(right),
            };
        }

        Ok(left)
    }

    fn parse_unary(&mut self) -> Result<Expr, String> {
        if self.match_token(&Token::Not) {
            let expr = self.parse_unary()?;
            return Ok(Expr::Unary {
                op: UnaryOp::Not,
                expr: Box::new(expr),
            });
        }
        if self.match_token(&Token::Minus) {
            let expr = self.parse_unary()?;
            return Ok(Expr::Unary {
                op: UnaryOp::Negate,
                expr: Box::new(expr),
            });
        }

        self.parse_apply()
    }

    fn parse_apply(&mut self) -> Result<Expr, String> {
        let mut func = self.parse_select()?;

        while self.is_start_of_primary() {
            let arg = self.parse_select()?;
            func = Expr::Apply {
                func: Box::new(func),
                arg: Box::new(arg),
            };
        }

        Ok(func)
    }

    fn is_start_of_primary(&self) -> bool {
        matches!(
            self.peek(),
            Token::Ident(_)
                | Token::Int(_)
                | Token::Str(_)
                | Token::Bool(_)
                | Token::Null
                | Token::OpenParen
                | Token::OpenBracket
                | Token::OpenBrace
                | Token::Rec
        )
    }

    fn parse_select(&mut self) -> Result<Expr, String> {
        let mut expr = self.parse_primary()?;

        while self.match_token(&Token::Dot) {
            let mut path = Vec::new();
            match self.peek().clone() {
                Token::Ident(id) => {
                    self.advance();
                    path.push(id);
                }
                Token::Str(s) => {
                    self.advance();
                    path.push(s);
                }
                Token::DollarBrace => {
                    self.advance(); // consume ${
                    let mut inner = String::new();
                    while !self.check(&Token::CloseBrace) && !self.check(&Token::Eof) {
                        match self.advance() {
                            Token::Ident(name) => inner.push_str(&name),
                            Token::Str(s) => inner.push_str(&s),
                            Token::Dot => inner.push('.'),
                            other => inner.push_str(&format!("{:?}", other)),
                        }
                    }
                    self.expect(&Token::CloseBrace)?;
                    path.push(inner);
                }
                other => {
                    return Err(format!(
                        "Expected identifier after '.' in attribute selection, found {:?}",
                        other
                    ));
                }
            }

            let mut default = None;
            if self.match_token(&Token::Or) {
                default = Some(Box::new(self.parse_primary()?));
            }

            expr = Expr::Select {
                expr: Box::new(expr),
                attr_path: path,
                default,
            };
        }

        Ok(expr)
    }

    fn parse_primary(&mut self) -> Result<Expr, String> {
        let tok = self.peek().clone();
        match tok {
            Token::Int(n) => {
                self.advance();
                Ok(Expr::Lit(Literal::Int(n)))
            }
            Token::Str(s) => {
                self.advance();
                Ok(Expr::Lit(Literal::Str(s)))
            }
            Token::Bool(b) => {
                self.advance();
                Ok(Expr::Lit(Literal::Bool(b)))
            }
            Token::Null => {
                self.advance();
                Ok(Expr::Lit(Literal::Null))
            }
            Token::Ident(name) => {
                self.advance();
                Ok(Expr::Ident(name))
            }
            Token::OpenParen => {
                self.advance(); // consume '('
                let inner = self.parse_expression()?;
                self.expect(&Token::CloseParen)?;
                Ok(inner)
            }
            Token::OpenBracket => {
                // List: [ e1 e2 ... ]
                self.advance(); // consume '['
                let mut items = Vec::new();
                while !self.check(&Token::CloseBracket) && !self.check(&Token::Eof) {
                    items.push(self.parse_select()?);
                }
                self.expect(&Token::CloseBracket)?;
                Ok(Expr::List(items))
            }
            Token::Rec | Token::OpenBrace => {
                // Attribute Set: { a = 1; b = 2; } or rec { ... }
                let is_rec = self.match_token(&Token::Rec);
                self.expect(&Token::OpenBrace)?;
                let mut entries = Vec::new();
                while !self.check(&Token::CloseBrace) && !self.check(&Token::Eof) {
                    if self.match_token(&Token::Inherit) {
                        let inherited = self.parse_inherit_entries()?;
                        entries.extend(inherited);
                    } else {
                        entries.push(self.parse_attr_entry()?);
                    }
                }
                self.expect(&Token::CloseBrace)?;
                Ok(Expr::AttrSet { is_rec, entries })
            }
            _ => Err(format!("Unexpected token in expression: {:?}", tok)),
        }
    }

    fn parse_attr_entry(&mut self) -> Result<AttrEntry, String> {
        let mut path = Vec::new();
        loop {
            match self.advance() {
                Token::Ident(id) => path.push(id),
                Token::Str(s) => path.push(s),
                Token::DollarBrace => {
                    let mut inner = String::new();
                    while !self.check(&Token::CloseBrace) && !self.check(&Token::Eof) {
                        match self.advance() {
                            Token::Ident(name) => inner.push_str(&name),
                            Token::Str(s) => inner.push_str(&s),
                            Token::Dot => inner.push('.'),
                            other => inner.push_str(&format!("{:?}", other)),
                        }
                    }
                    self.expect(&Token::CloseBrace)?;
                    path.push(inner);
                }
                other => return Err(format!("Expected attribute key identifier, found {:?}", other)),
            }
            if !self.match_token(&Token::Dot) {
                break;
            }
        }
        self.expect(&Token::Assign)?;
        let value = self.parse_expression()?;
        self.expect(&Token::Semicolon)?;
        Ok(AttrEntry { path, value })
    }

    fn parse_inherit_entries(&mut self) -> Result<Vec<AttrEntry>, String> {
        let from_expr = if self.match_token(&Token::OpenParen) {
            let expr = self.parse_expression()?;
            self.expect(&Token::CloseParen)?;
            Some(expr)
        } else {
            None
        };

        let mut entries = Vec::new();
        while !self.check(&Token::Semicolon) && !self.check(&Token::Eof) {
            if let Token::Ident(name) = self.advance() {
                let value = match &from_expr {
                    Some(src) => Expr::Select {
                        expr: Box::new(src.clone()),
                        attr_path: vec![name.clone()],
                        default: None,
                    },
                    None => Expr::Ident(name.clone()),
                };
                entries.push(AttrEntry {
                    path: vec![name],
                    value,
                });
            } else {
                return Err("Expected identifier in inherit statement".to_string());
            }
        }
        self.expect(&Token::Semicolon)?;
        Ok(entries)
    }
}
