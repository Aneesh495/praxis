// Praxis Execution Engine
// Nix Lexer: High-Speed Lexical Tokenizer for Nix Expressions

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Ident(String),
    Int(i64),
    Str(String),
    Bool(bool),
    Null,

    // Keywords
    Let,
    In,
    Rec,
    Inherit,
    If,
    Then,
    Else,
    With,
    Assert,

    // Punctuation
    OpenBrace,    // {
    CloseBrace,   // }
    OpenBracket,  // [
    CloseBracket, // ]
    OpenParen,    // (
    CloseParen,   // )
    Semicolon,    // ;
    Colon,        // :
    Comma,        // ,
    Dot,          // .
    Assign,       // =
    Question,     // ?
    At,           // @

    // Operators
    Update,       // //
    Concat,       // ++
    Equal,        // ==
    NotEqual,     // !=
    Less,         // <
    LessEqual,    // <=
    Greater,      // >
    GreaterEqual, // >=
    And,          // &&
    Or,           // ||
    Not,          // !
    Implies,      // ->
    Plus,         // +
    Minus,        // -
    Multiply,     // *
    Divide,       // /

    Eof,
}

pub struct Lexer<'a> {
    _phantom: std::marker::PhantomData<&'a ()>,
    chars: Vec<char>,
    pos: usize,
}

impl<'a> Lexer<'a> {
    pub fn new(input: &'a str) -> Self {
        Self {
            _phantom: std::marker::PhantomData,
            chars: input.chars().collect(),
            pos: 0,
        }
    }

    fn peek(&self) -> Option<char> {
        self.chars.get(self.pos).copied()
    }

    fn peek_next(&self) -> Option<char> {
        self.chars.get(self.pos + 1).copied()
    }

    fn advance(&mut self) -> Option<char> {
        let ch = self.peek();
        if ch.is_some() {
            self.pos += 1;
        }
        ch
    }

    fn skip_whitespace_and_comments(&mut self) {
        while let Some(ch) = self.peek() {
            if ch.is_whitespace() {
                self.advance();
            } else if ch == '#' {
                // Line comment
                while let Some(c) = self.advance() {
                    if c == '\n' {
                        break;
                    }
                }
            } else if ch == '/' && self.peek_next() == Some('*') {
                // Block comment
                self.advance(); // consume '/'
                self.advance(); // consume '*'
                while let Some(c) = self.advance() {
                    if c == '*' && self.peek() == Some('/') {
                        self.advance();
                        break;
                    }
                }
            } else {
                break;
            }
        }
    }

    pub fn next_token(&mut self) -> Result<Token, String> {
        self.skip_whitespace_and_comments();

        let ch = match self.peek() {
            Some(c) => c,
            None => return Ok(Token::Eof),
        };

        // Identifiers and Keywords
        if ch.is_alphabetic() || ch == '_' {
            let mut ident = String::new();
            while let Some(c) = self.peek() {
                if c.is_alphanumeric() || c == '_' || c == '-' {
                    ident.push(c);
                    self.advance();
                } else {
                    break;
                }
            }
            return Ok(match ident.as_str() {
                "let" => Token::Let,
                "in" => Token::In,
                "rec" => Token::Rec,
                "inherit" => Token::Inherit,
                "if" => Token::If,
                "then" => Token::Then,
                "else" => Token::Else,
                "with" => Token::With,
                "assert" => Token::Assert,
                "true" => Token::Bool(true),
                "false" => Token::Bool(false),
                "null" => Token::Null,
                _ => Token::Ident(ident),
            });
        }

        // Numbers
        if ch.is_numeric() {
            let mut num_str = String::new();
            while let Some(c) = self.peek() {
                if c.is_numeric() {
                    num_str.push(c);
                    self.advance();
                } else {
                    break;
                }
            }
            let val = num_str.parse::<i64>().map_err(|e| e.to_string())?;
            return Ok(Token::Int(val));
        }

        // String literals ("...")
        if ch == '"' {
            self.advance(); // Consume opening quote
            let mut s = String::new();
            while let Some(c) = self.advance() {
                if c == '"' {
                    return Ok(Token::Str(s));
                } else if c == '\\' {
                    if let Some(escaped) = self.advance() {
                        match escaped {
                            'n' => s.push('\n'),
                            'r' => s.push('\r'),
                            't' => s.push('\t'),
                            '\\' => s.push('\\'),
                            '"' => s.push('"'),
                            '$' => s.push('$'),
                            other => {
                                s.push('\\');
                                s.push(other);
                            }
                        }
                    }
                } else {
                    s.push(c);
                }
            }
            return Err("Unterminated string literal".to_string());
        }

        // Multi-char operators and single punctuation
        self.advance();
        match ch {
            '{' => Ok(Token::OpenBrace),
            '}' => Ok(Token::CloseBrace),
            '[' => Ok(Token::OpenBracket),
            ']' => Ok(Token::CloseBracket),
            '(' => Ok(Token::OpenParen),
            ')' => Ok(Token::CloseParen),
            ';' => Ok(Token::Semicolon),
            ':' => Ok(Token::Colon),
            ',' => Ok(Token::Comma),
            '.' => Ok(Token::Dot),
            '?' => Ok(Token::Question),
            '@' => Ok(Token::At),
            '+' => {
                if self.peek() == Some('+') {
                    self.advance();
                    Ok(Token::Concat)
                } else {
                    Ok(Token::Plus)
                }
            }
            '-' => {
                if self.peek() == Some('>') {
                    self.advance();
                    Ok(Token::Implies)
                } else {
                    Ok(Token::Minus)
                }
            }
            '*' => Ok(Token::Multiply),
            '/' => {
                if self.peek() == Some('/') {
                    self.advance();
                    Ok(Token::Update)
                } else {
                    Ok(Token::Divide)
                }
            }
            '=' => {
                if self.peek() == Some('=') {
                    self.advance();
                    Ok(Token::Equal)
                } else {
                    Ok(Token::Assign)
                }
            }
            '!' => {
                if self.peek() == Some('=') {
                    self.advance();
                    Ok(Token::NotEqual)
                } else {
                    Ok(Token::Not)
                }
            }
            '<' => {
                if self.peek() == Some('=') {
                    self.advance();
                    Ok(Token::LessEqual)
                } else {
                    Ok(Token::Less)
                }
            }
            '>' => {
                if self.peek() == Some('=') {
                    self.advance();
                    Ok(Token::GreaterEqual)
                } else {
                    Ok(Token::Greater)
                }
            }
            '&' => {
                if self.peek() == Some('&') {
                    self.advance();
                    Ok(Token::And)
                } else {
                    Err(format!("Unexpected character: {}", ch))
                }
            }
            '|' => {
                if self.peek() == Some('|') {
                    self.advance();
                    Ok(Token::Or)
                } else {
                    Err(format!("Unexpected character: {}", ch))
                }
            }
            _ => Err(format!("Unexpected character: {}", ch)),
        }
    }

    pub fn tokenize(&mut self) -> Result<Vec<Token>, String> {
        let mut tokens = Vec::new();
        loop {
            let tok = self.next_token()?;
            if tok == Token::Eof {
                tokens.push(tok);
                break;
            }
            tokens.push(tok);
        }
        Ok(tokens)
    }
}

impl Token {
    pub fn clone_eof() -> Self {
        Token::Eof
    }
}
