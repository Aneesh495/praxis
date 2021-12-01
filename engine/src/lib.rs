// Praxis Execution Engine Library Root
//
// Standalone pure-Nix execution engine, AST parser, lazy evaluator,
// microVM hypervisor simulator, and zero-trust infrastructure synthesizers.

pub mod evaluator;
pub mod generators;
pub mod nix_ast;
pub mod simulator;
pub mod ui;
pub mod validator;

pub use evaluator::{eval_nix_source, Evaluator, Value};
pub use nix_ast::{parse_nix, Expr};
pub use simulator::{MicroVmSimulator, NetworkSimulator, RaftClusterSimulator};
pub use validator::{Linter, SchemaValidator};
