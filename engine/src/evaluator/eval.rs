// Praxis Execution Engine
// Evaluator: Lazy Nix Evaluator with Call-By-Need Semantics and Cycle Detection

use std::collections::BTreeMap;
use super::builtins::{call_builtin, make_builtins_set};
use super::scope::Scope;
use super::value::{ThunkState, Value};
use crate::nix_ast::ast::*;

pub struct Evaluator;

impl Evaluator {
    pub fn new() -> Self {
        Self
    }

    pub fn new_global_scope(&self) -> Scope {
        let scope = Scope::new();
        let builtins_map = make_builtins_set();
        scope.insert("builtins".to_string(), Value::Attrs(builtins_map));
        scope
    }

    pub fn force(&self, val: &Value) -> Result<Value, String> {
        match val {
            Value::Thunk(rc_thunk) => {
                let state = { rc_thunk.borrow().clone() };
                match state {
                    ThunkState::Evaluated(v) => Ok(v),
                    ThunkState::Evaluating => {
                        Err("Infinite recursion / cycle detected during lazy evaluation".to_string())
                    }
                    ThunkState::Unevaluated(expr, scope) => {
                        *rc_thunk.borrow_mut() = ThunkState::Evaluating;
                        let evaluated = self.eval(&expr, &scope)?;
                        let forced = self.force(&evaluated)?;
                        *rc_thunk.borrow_mut() = ThunkState::Evaluated(forced.clone());
                        Ok(forced)
                    }
                }
            }
            other => Ok(other.clone()),
        }
    }

    pub fn force_deep(&self, val: &Value) -> Result<Value, String> {
        let forced = self.force(val)?;
        match forced {
            Value::List(items) => {
                let mut deep_items = Vec::new();
                for item in items {
                    deep_items.push(self.force_deep(&item)?);
                }
                Ok(Value::List(deep_items))
            }
            Value::Attrs(attrs) => {
                let mut deep_attrs = BTreeMap::new();
                for (k, v) in attrs {
                    deep_attrs.insert(k, self.force_deep(&v)?);
                }
                Ok(Value::Attrs(deep_attrs))
            }
            other => Ok(other),
        }
    }

    pub fn eval(&self, expr: &Expr, scope: &Scope) -> Result<Value, String> {
        match expr {
            Expr::Lit(lit) => Ok(match lit {
                Literal::Int(n) => Value::Int(*n),
                Literal::Str(s) => Value::Str(s.clone()),
                Literal::Bool(b) => Value::Bool(*b),
                Literal::Null => Value::Null,
            }),

            Expr::Ident(name) => {
                if let Some(val) = scope.lookup(name) {
                    self.force(&val)
                } else {
                    Err(format!("Undefined variable: '{}'", name))
                }
            }

            Expr::List(items) => {
                let mut list = Vec::new();
                for item in items {
                    list.push(Value::thunk(item.clone(), scope.clone()));
                }
                Ok(Value::List(list))
            }

            Expr::AttrSet { is_rec, entries } => {
                let eval_scope = if *is_rec { scope.child() } else { scope.clone() };
                let mut map = BTreeMap::new();

                for entry in entries {
                    if let Some(first_key) = entry.path.first() {
                        let thunk = Value::thunk(entry.value.clone(), eval_scope.clone());
                        map.insert(first_key.clone(), thunk.clone());
                        if *is_rec {
                            eval_scope.insert(first_key.clone(), thunk);
                        }
                    }
                }

                Ok(Value::Attrs(map))
            }

            Expr::LetIn { bindings, body } => {
                let let_scope = scope.child();
                for entry in bindings {
                    if let Some(first_key) = entry.path.first() {
                        let thunk = Value::thunk(entry.value.clone(), let_scope.clone());
                        let_scope.insert(first_key.clone(), thunk);
                    }
                }
                self.eval(body, &let_scope)
            }

            Expr::IfThenElse {
                cond,
                then_branch,
                else_branch,
            } => {
                let cond_val = self.force(&self.eval(cond, scope)?)?;
                match cond_val {
                    Value::Bool(true) => self.eval(then_branch, scope),
                    Value::Bool(false) => self.eval(else_branch, scope),
                    _ => Err(format!(
                        "Condition does not evaluate to boolean: found {}",
                        cond_val.type_of()
                    )),
                }
            }

            Expr::Lambda { pattern, body } => Ok(Value::Lambda {
                pattern: pattern.clone(),
                body: body.clone(),
                captured_scope: scope.clone(),
            }),

            Expr::Apply { func, arg } => {
                let func_val = self.force(&self.eval(func, scope)?)?;
                match func_val {
                    Value::Lambda {
                        pattern,
                        body,
                        captured_scope,
                    } => {
                        let call_scope = captured_scope.child();
                        let arg_thunk = Value::thunk(*arg.clone(), scope.clone());

                        match pattern {
                            Pattern::Simple(name) => {
                                call_scope.insert(name, arg_thunk);
                            }
                            Pattern::Formals {
                                args,
                                ellipsis: _,
                                binding,
                            } => {
                                if let Some(bind_name) = binding {
                                    call_scope.insert(bind_name, arg_thunk.clone());
                                }
                                let forced_arg = self.force(&arg_thunk)?;
                                if let Value::Attrs(arg_attrs) = forced_arg {
                                    for (formal_name, default_expr) in args {
                                        if let Some(val) = arg_attrs.get(&formal_name) {
                                            call_scope.insert(formal_name, val.clone());
                                        } else if let Some(def) = default_expr {
                                            let def_thunk =
                                                Value::thunk(def, captured_scope.clone());
                                            call_scope.insert(formal_name, def_thunk);
                                        } else {
                                            return Err(format!(
                                                "Missing mandatory argument '{}' in function call",
                                                formal_name
                                            ));
                                        }
                                    }
                                } else {
                                    return Err("Function expects attribute set argument".to_string());
                                }
                            }
                        }

                        self.eval(&body, &call_scope)
                    }
                    Value::Builtin { name, arity, mut args } => {
                        let forced_arg = self.force(&self.eval(arg, scope)?)?;
                        args.push(forced_arg);
                        if args.len() >= arity {
                            call_builtin(&name, &args)
                        } else {
                            Ok(Value::Builtin { name, arity, args })
                        }
                    }
                    other => Err(format!("Attempt to call non-function: {}", other.type_of())),
                }
            }

            Expr::BinOp { op, left, right } => {
                let l_val = self.force(&self.eval(left, scope)?)?;
                let r_val = self.force(&self.eval(right, scope)?)?;

                match op {
                    BinaryOp::Add => match (l_val, r_val) {
                        (Value::Int(a), Value::Int(b)) => Ok(Value::Int(a + b)),
                        (Value::Str(a), Value::Str(b)) => Ok(Value::Str(format!("{}{}", a, b))),
                        _ => Err("Invalid operand types for '+'".to_string()),
                    },
                    BinaryOp::Sub => match (l_val, r_val) {
                        (Value::Int(a), Value::Int(b)) => Ok(Value::Int(a - b)),
                        _ => Err("Invalid operand types for '-'".to_string()),
                    },
                    BinaryOp::Mul => match (l_val, r_val) {
                        (Value::Int(a), Value::Int(b)) => Ok(Value::Int(a * b)),
                        _ => Err("Invalid operand types for '*'".to_string()),
                    },
                    BinaryOp::Div => match (l_val, r_val) {
                        (Value::Int(a), Value::Int(b)) => {
                            if b == 0 {
                                Err("Division by zero".to_string())
                            } else {
                                Ok(Value::Int(a / b))
                            }
                        }
                        _ => Err("Invalid operand types for '/'".to_string()),
                    },
                    BinaryOp::Update => match (l_val, r_val) {
                        (Value::Attrs(mut a), Value::Attrs(b)) => {
                            for (k, v) in b {
                                a.insert(k, v);
                            }
                            Ok(Value::Attrs(a))
                        }
                        _ => Err("Both operands of '//' must be attribute sets".to_string()),
                    },
                    BinaryOp::Concat => match (l_val, r_val) {
                        (Value::List(mut a), Value::List(b)) => {
                            a.extend(b);
                            Ok(Value::List(a))
                        }
                        _ => Err("Both operands of '++' must be lists".to_string()),
                    },
                    BinaryOp::Equal => Ok(Value::Bool(self.values_equal(&l_val, &r_val)?)),
                    BinaryOp::NotEqual => Ok(Value::Bool(!self.values_equal(&l_val, &r_val)?)),
                    BinaryOp::Less => match (l_val, r_val) {
                        (Value::Int(a), Value::Int(b)) => Ok(Value::Bool(a < b)),
                        (Value::Str(a), Value::Str(b)) => Ok(Value::Bool(a < b)),
                        _ => Err("Incomparable types for '<'".to_string()),
                    },
                    BinaryOp::LessEqual => match (l_val, r_val) {
                        (Value::Int(a), Value::Int(b)) => Ok(Value::Bool(a <= b)),
                        (Value::Str(a), Value::Str(b)) => Ok(Value::Bool(a <= b)),
                        _ => Err("Incomparable types for '<='".to_string()),
                    },
                    BinaryOp::Greater => match (l_val, r_val) {
                        (Value::Int(a), Value::Int(b)) => Ok(Value::Bool(a > b)),
                        (Value::Str(a), Value::Str(b)) => Ok(Value::Bool(a > b)),
                        _ => Err("Incomparable types for '>'".to_string()),
                    },
                    BinaryOp::GreaterEqual => match (l_val, r_val) {
                        (Value::Int(a), Value::Int(b)) => Ok(Value::Bool(a >= b)),
                        (Value::Str(a), Value::Str(b)) => Ok(Value::Bool(a >= b)),
                        _ => Err("Incomparable types for '>='".to_string()),
                    },
                    BinaryOp::And => match (l_val, r_val) {
                        (Value::Bool(a), Value::Bool(b)) => Ok(Value::Bool(a && b)),
                        _ => Err("Operands of '&&' must be booleans".to_string()),
                    },
                    BinaryOp::Or => match (l_val, r_val) {
                        (Value::Bool(a), Value::Bool(b)) => Ok(Value::Bool(a || b)),
                        _ => Err("Operands of '||' must be booleans".to_string()),
                    },
                    BinaryOp::HasAttr => match (l_val, r_val) {
                        (Value::Attrs(attrs), Value::Str(key)) => Ok(Value::Bool(attrs.contains_key(&key))),
                        _ => Err("Left of '?' must be set and right must be string".to_string()),
                    },
                    BinaryOp::Implies => match (l_val, r_val) {
                        (Value::Bool(a), Value::Bool(b)) => Ok(Value::Bool(!a || b)),
                        _ => Err("Operands of '->' must be booleans".to_string()),
                    },
                }
            }

            Expr::Select {
                expr,
                attr_path,
                default,
            } => {
                let mut current = self.force(&self.eval(expr, scope)?)?;
                for segment in attr_path {
                    match current {
                        Value::Attrs(attrs) => {
                            if let Some(val) = attrs.get(segment) {
                                current = self.force(val)?;
                            } else if let Some(def_expr) = default {
                                return self.eval(def_expr, scope);
                            } else {
                                return Err(format!("Attribute '{}' not found in attribute set", segment));
                            }
                        }
                        _ => {
                            if let Some(def_expr) = default {
                                return self.eval(def_expr, scope);
                            } else {
                                return Err(format!("Cannot select attribute from non-set: {}", current.type_of()));
                            }
                        }
                    }
                }
                Ok(current)
            }

            Expr::Unary { op, expr } => {
                let val = self.force(&self.eval(expr, scope)?)?;
                match op {
                    UnaryOp::Negate => match val {
                        Value::Int(n) => Ok(Value::Int(-n)),
                        _ => Err("Operand of '-' must be an integer".to_string()),
                    },
                    UnaryOp::Not => match val {
                        Value::Bool(b) => Ok(Value::Bool(!b)),
                        _ => Err("Operand of '!' must be a boolean".to_string()),
                    },
                }
            }

            Expr::With { env, body } => {
                let env_val = self.force(&self.eval(env, scope)?)?;
                let with_scope = scope.child();
                with_scope.add_with(env_val);
                self.eval(body, &with_scope)
            }

            Expr::Assert { cond, body } => {
                let cond_val = self.force(&self.eval(cond, scope)?)?;
                match cond_val {
                    Value::Bool(true) => self.eval(body, scope),
                    Value::Bool(false) => Err("Assertion failed".to_string()),
                    _ => Err("Assertion condition must be boolean".to_string()),
                }
            }
        }
    }

    fn values_equal(&self, a: &Value, b: &Value) -> Result<bool, String> {
        let fa = self.force(a)?;
        let fb = self.force(b)?;
        match (fa, fb) {
            (Value::Null, Value::Null) => Ok(true),
            (Value::Bool(x), Value::Bool(y)) => Ok(x == y),
            (Value::Int(x), Value::Int(y)) => Ok(x == y),
            (Value::Str(x), Value::Str(y)) => Ok(x == y),
            (Value::List(x), Value::List(y)) => {
                if x.len() != y.len() {
                    return Ok(false);
                }
                for (ix, iy) in x.iter().zip(y.iter()) {
                    if !self.values_equal(ix, iy)? {
                        return Ok(false);
                    }
                }
                Ok(true)
            }
            (Value::Attrs(x), Value::Attrs(y)) => {
                if x.len() != y.len() {
                    return Ok(false);
                }
                for (k, vx) in &x {
                    if let Some(vy) = y.get(k) {
                        if !self.values_equal(vx, vy)? {
                            return Ok(false);
                        }
                    } else {
                        return Ok(false);
                    }
                }
                Ok(true)
            }
            _ => Ok(false),
        }
    }
}
