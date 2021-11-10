// Praxis Execution Engine
// Evaluator: Lexical Environment Scopes and With-Bindings

use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

use super::value::Value;

#[derive(Clone)]
pub struct Scope {
    inner: Rc<RefCell<ScopeInner>>,
}

struct ScopeInner {
    bindings: HashMap<String, Value>,
    parent: Option<Scope>,
    with_attrs: Vec<Value>,
}

impl Scope {
    pub fn new() -> Self {
        Self {
            inner: Rc::new(RefCell::new(ScopeInner {
                bindings: HashMap::new(),
                parent: None,
                with_attrs: Vec::new(),
            })),
        }
    }

    pub fn child(&self) -> Self {
        Self {
            inner: Rc::new(RefCell::new(ScopeInner {
                bindings: HashMap::new(),
                parent: Some(self.clone()),
                with_attrs: Vec::new(),
            })),
        }
    }

    pub fn insert(&self, name: String, val: Value) {
        self.inner.borrow_mut().bindings.insert(name, val);
    }

    pub fn add_with(&self, val: Value) {
        self.inner.borrow_mut().with_attrs.push(val);
    }

    pub fn lookup(&self, name: &str) -> Option<Value> {
        let borrowed = self.inner.borrow();
        if let Some(val) = borrowed.bindings.get(name) {
            return Some(val.clone());
        }

        // Check with-scopes in reverse order (most recent first)
        for with_val in borrowed.with_attrs.iter().rev() {
            if let Value::Attrs(attrs) = with_val {
                if let Some(v) = attrs.get(name) {
                    return Some(v.clone());
                }
            }
        }

        if let Some(ref parent) = borrowed.parent {
            parent.lookup(name)
        } else {
            None
        }
    }
}
