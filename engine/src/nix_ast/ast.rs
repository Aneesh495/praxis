// Praxis Execution Engine
// Nix AST: Abstract Syntax Tree Nodes for Nix Expressions

#[derive(Debug, Clone, PartialEq)]
pub enum Literal {
    Int(i64),
    Str(String),
    Bool(bool),
    Null,
}

#[derive(Debug, Clone, PartialEq)]
pub enum BinaryOp {
    Add,
    Sub,
    Mul,
    Div,
    Concat,
    Update,
    Equal,
    NotEqual,
    Less,
    LessEqual,
    Greater,
    GreaterEqual,
    And,
    Or,
    Implies,
    HasAttr,
}

#[derive(Debug, Clone, PartialEq)]
pub enum UnaryOp {
    Negate,
    Not,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Pattern {
    Simple(String),
    Formals {
        args: Vec<(String, Option<Expr>)>,
        ellipsis: bool,
        binding: Option<String>,
    },
}

#[derive(Debug, Clone, PartialEq)]
pub struct AttrEntry {
    pub path: Vec<String>,
    pub value: Expr,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Expr {
    Lit(Literal),
    Ident(String),
    List(Vec<Expr>),
    AttrSet {
        is_rec: bool,
        entries: Vec<AttrEntry>,
    },
    LetIn {
        bindings: Vec<AttrEntry>,
        body: Box<Expr>,
    },
    IfThenElse {
        cond: Box<Expr>,
        then_branch: Box<Expr>,
        else_branch: Box<Expr>,
    },
    Lambda {
        pattern: Pattern,
        body: Box<Expr>,
    },
    Apply {
        func: Box<Expr>,
        arg: Box<Expr>,
    },
    BinOp {
        op: BinaryOp,
        left: Box<Expr>,
        right: Box<Expr>,
    },
    Unary {
        op: UnaryOp,
        expr: Box<Expr>,
    },
    Select {
        expr: Box<Expr>,
        attr_path: Vec<String>,
        default: Option<Box<Expr>>,
    },
    With {
        env: Box<Expr>,
        body: Box<Expr>,
    },
    Assert {
        cond: Box<Expr>,
        body: Box<Expr>,
    },
}
