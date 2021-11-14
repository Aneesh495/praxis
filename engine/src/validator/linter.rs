// Praxis Execution Engine
// Validator: Static AST Linter and Dead Code Detector

use std::collections::HashSet;
use crate::nix_ast::ast::*;

#[derive(Debug)]
pub struct LintWarning {
    pub rule: &'static str,
    pub message: String,
}

pub struct Linter;

impl Linter {
    pub fn new() -> Self {
        Self
    }

    pub fn lint(&self, expr: &Expr) -> Vec<LintWarning> {
        let mut warnings = Vec::new();
        self.traverse(expr, &mut warnings);
        warnings
    }

    fn traverse(&self, expr: &Expr, warnings: &mut Vec<LintWarning>) {
        match expr {
            Expr::LetIn { bindings, body } => {
                let mut bound_names = HashSet::new();
                for entry in bindings {
                    if let Some(first_key) = entry.path.first() {
                        bound_names.insert(first_key.clone());
                    }
                    self.traverse(&entry.value, warnings);
                }

                // Check if variables in let-in are referenced in body
                let mut used_in_body = HashSet::new();
                self.collect_identifiers(body, &mut used_in_body);

                for name in bound_names {
                    if !used_in_body.contains(&name) {
                        warnings.push(LintWarning {
                            rule: "unused-let-binding",
                            message: format!("Variable '{}' declared in let-block is never referenced in body", name),
                        });
                    }
                }

                self.traverse(body, warnings);
            }

            Expr::IfThenElse {
                cond,
                then_branch,
                else_branch,
            } => {
                if let Expr::Lit(Literal::Bool(b)) = **cond {
                    warnings.push(LintWarning {
                        rule: "constant-if-condition",
                        message: format!("Conditional expression is statically constant ({})", b),
                    });
                }
                self.traverse(cond, warnings);
                self.traverse(then_branch, warnings);
                self.traverse(else_branch, warnings);
            }

            Expr::List(items) => {
                for item in items {
                    self.traverse(item, warnings);
                }
            }

            Expr::AttrSet { entries, .. } => {
                for entry in entries {
                    self.traverse(&entry.value, warnings);
                }
            }

            Expr::Lambda { body, .. } => {
                self.traverse(body, warnings);
            }

            Expr::Apply { func, arg } => {
                self.traverse(func, warnings);
                self.traverse(arg, warnings);
            }

            Expr::BinOp { left, right, .. } => {
                self.traverse(left, warnings);
                self.traverse(right, warnings);
            }

            Expr::Unary { expr, .. } => {
                self.traverse(expr, warnings);
            }

            Expr::Select { expr, default, .. } => {
                self.traverse(expr, warnings);
                if let Some(d) = default {
                    self.traverse(d, warnings);
                }
            }

            Expr::With { env, body } => {
                self.traverse(env, warnings);
                self.traverse(body, warnings);
            }

            Expr::Assert { cond, body } => {
                self.traverse(cond, warnings);
                self.traverse(body, warnings);
            }

            Expr::Lit(_) | Expr::Ident(_) => {}
        }
    }

    fn collect_identifiers(&self, expr: &Expr, idents: &mut HashSet<String>) {
        match expr {
            Expr::Ident(name) => {
                idents.insert(name.clone());
            }
            Expr::Apply { func, arg } => {
                self.collect_identifiers(func, idents);
                self.collect_identifiers(arg, idents);
            }
            Expr::BinOp { left, right, .. } => {
                self.collect_identifiers(left, idents);
                self.collect_identifiers(right, idents);
            }
            Expr::List(items) => {
                for i in items {
                    self.collect_identifiers(i, idents);
                }
            }
            Expr::AttrSet { entries, .. } => {
                for e in entries {
                    self.collect_identifiers(&e.value, idents);
                }
            }
            Expr::LetIn { bindings, body } => {
                for b in bindings {
                    self.collect_identifiers(&b.value, idents);
                }
                self.collect_identifiers(body, idents);
            }
            Expr::IfThenElse {
                cond,
                then_branch,
                else_branch,
            } => {
                self.collect_identifiers(cond, idents);
                self.collect_identifiers(then_branch, idents);
                self.collect_identifiers(else_branch, idents);
            }
            Expr::Select { expr, default, .. } => {
                self.collect_identifiers(expr, idents);
                if let Some(d) = default {
                    self.collect_identifiers(d, idents);
                }
            }
            _ => {}
        }
    }
}
