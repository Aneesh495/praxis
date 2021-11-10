// Praxis Execution Engine
// Evaluator: Dynamic Nix Value Representation and Lazy Thunks

use std::cell::RefCell;
use std::collections::BTreeMap;
use std::rc::Rc;

use super::scope::Scope;
use crate::nix_ast::ast::{Expr, Pattern};

#[derive(Clone)]
pub enum ThunkState {
    Unevaluated(Box<Expr>, Scope),
    Evaluating,
    Evaluated(Value),
}

#[derive(Clone)]
pub enum Value {
    Null,
    Bool(bool),
    Int(i64),
    Str(String),
    List(Vec<Value>),
    Attrs(BTreeMap<String, Value>),
    Lambda {
        pattern: Pattern,
        body: Box<Expr>,
        captured_scope: Scope,
    },
    Thunk(Rc<RefCell<ThunkState>>),
    Builtin {
        name: String,
        arity: usize,
        args: Vec<Value>,
    },
}

impl Value {
    pub fn thunk(expr: Expr, scope: Scope) -> Self {
        Value::Thunk(Rc::new(RefCell::new(ThunkState::Unevaluated(
            Box::new(expr),
            scope,
        ))))
    }

    pub fn type_of(&self) -> &'static str {
        match self {
            Value::Null => "null",
            Value::Bool(_) => "bool",
            Value::Int(_) => "int",
            Value::Str(_) => "string",
            Value::List(_) => "list",
            Value::Attrs(_) => "set",
            Value::Lambda { .. } | Value::Builtin { .. } => "lambda",
            Value::Thunk(_) => "thunk",
        }
    }

    pub fn to_string_repr(&self) -> String {
        match self {
            Value::Null => "null".to_string(),
            Value::Bool(b) => b.to_string(),
            Value::Int(n) => n.to_string(),
            Value::Str(s) => format!("\"{}\"", s),
            Value::List(items) => {
                let inner: Vec<String> = items.iter().map(|i| i.to_string_repr()).collect();
                format!("[ {} ]", inner.join(" "))
            }
            Value::Attrs(attrs) => {
                let mut entries = Vec::new();
                for (k, v) in attrs {
                    entries.push(format!("{} = {};", k, v.to_string_repr()));
                }
                format!("{{ {} }}", entries.join(" "))
            }
            Value::Lambda { .. } => "<LAMBDA>".to_string(),
            Value::Builtin { name, .. } => format!("<BUILTIN:{}>", name),
            Value::Thunk(_) => "<THUNK>".to_string(),
        }
    }
}
