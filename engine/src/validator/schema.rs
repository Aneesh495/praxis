// Praxis Execution Engine
// Validator: Structural Schema and Invariant Contract Verification

use std::collections::BTreeMap;
use crate::evaluator::Value;

#[derive(Debug)]
pub struct ValidationError {
    pub location: String,
    pub message: String,
}

pub struct SchemaValidator;

impl SchemaValidator {
    pub fn new() -> Self {
        Self
    }

    pub fn validate_system_config(&self, root: &Value) -> Result<(), Vec<ValidationError>> {
        let mut errors = Vec::new();

        if let Value::Attrs(attrs) = root {
            // Check top-level 'praxis' namespace
            if let Some(praxis_val) = attrs.get("praxis") {
                if let Value::Attrs(praxis_attrs) = praxis_val {
                    self.check_microvm_subsystem(praxis_attrs, &mut errors);
                    self.check_network_subsystem(praxis_attrs, &mut errors);
                }
            }
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }

    fn check_microvm_subsystem(&self, praxis: &BTreeMap<String, Value>, errors: &mut Vec<ValidationError>) {
        if let Some(Value::Attrs(vm)) = praxis.get("microvm") {
            if let Some(Value::Attrs(vcpu)) = vm.get("vcpu") {
                if let Some(Value::Int(count)) = vcpu.get("count") {
                    if *count <= 0 || *count > 256 {
                        errors.push(ValidationError {
                            location: "praxis.microvm.vcpu.count".to_string(),
                            message: format!("vCPU count {} is invalid; must be between 1 and 256", count),
                        });
                    }
                }
            }

            if let Some(Value::Attrs(mem)) = vm.get("memory") {
                if let Some(Value::Int(size)) = mem.get("sizeMB") {
                    if *size < 128 {
                        errors.push(ValidationError {
                            location: "praxis.microvm.memory.sizeMB".to_string(),
                            message: format!("Memory size {} MB is below minimum required 128 MB", size),
                        });
                    }
                }
            }
        }
    }

    fn check_network_subsystem(&self, praxis: &BTreeMap<String, Value>, errors: &mut Vec<ValidationError>) {
        if let Some(Value::Attrs(net)) = praxis.get("network") {
            if let Some(Value::Attrs(wg)) = net.get("wireguard") {
                if let Some(Value::Int(port)) = wg.get("listenPort") {
                    if *port <= 0 || *port > 65535 {
                        errors.push(ValidationError {
                            location: "praxis.network.wireguard.listenPort".to_string(),
                            message: format!("Port {} is outside valid range 1-65535", port),
                        });
                    }
                }
            }
        }
    }
}
