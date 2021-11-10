// Praxis Execution Engine
// Evaluator Module: Lazy Evaluation, Builtins, and Dynamic Values

pub mod builtins;
pub mod eval;
pub mod scope;
pub mod value;

pub use eval::Evaluator;
pub use scope::Scope;
pub use value::Value;

pub fn eval_nix_source(source: &str) -> Result<Value, String> {
    let expr = crate::nix_ast::parse_nix(source)?;
    let evaluator = Evaluator::new();
    let global_scope = evaluator.new_global_scope();
    let val = evaluator.eval(&expr, &global_scope)?;
    evaluator.force_deep(&val)
}
