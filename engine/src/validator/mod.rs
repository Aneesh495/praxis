// Praxis Execution Engine
// Validator Module: Schema Invariants, Contract Checking, and AST Linter

pub mod linter;
pub mod schema;

pub use linter::{LintWarning, Linter};
pub use schema::{SchemaValidator, ValidationError};
