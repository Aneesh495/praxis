// Praxis Execution Engine
// Evaluator: Nix Standard Library Builtins (builtins.*)

use std::collections::BTreeMap;
use super::value::Value;

pub fn builtin_arity(name: &str) -> usize {
    match name {
        "substring" => 3,
        "elemAt" | "hasAttr" | "concatStringsSep" => 2,
        _ => 1,
    }
}

pub fn call_builtin(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
        "length" => {
            if let Some(Value::List(l)) = args.first() {
                Ok(Value::Int(l.len() as i64))
            } else {
                Err("builtins.length: expected list argument".to_string())
            }
        }
        "elemAt" => {
            if args.len() >= 2 {
                if let (Value::List(l), Value::Int(idx)) = (&args[0], &args[1]) {
                    if *idx >= 0 && (*idx as usize) < l.len() {
                        Ok(l[*idx as usize].clone())
                    } else {
                        Err(format!("builtins.elemAt: index {} out of bounds", idx))
                    }
                } else {
                    Err("builtins.elemAt: invalid argument types".to_string())
                }
            } else {
                Err("builtins.elemAt requires 2 arguments".to_string())
            }
        }
        "head" => {
            if let Some(Value::List(l)) = args.first() {
                l.first().cloned().ok_or_else(|| "builtins.head: empty list".to_string())
            } else {
                Err("builtins.head: expected list".to_string())
            }
        }
        "tail" => {
            if let Some(Value::List(l)) = args.first() {
                if l.is_empty() {
                    Err("builtins.tail: empty list".to_string())
                } else {
                    Ok(Value::List(l[1..].to_vec()))
                }
            } else {
                Err("builtins.tail: expected list".to_string())
            }
        }
        "attrNames" => {
            if let Some(Value::Attrs(attrs)) = args.first() {
                let keys: Vec<Value> = attrs.keys().map(|k| Value::Str(k.clone())).collect();
                Ok(Value::List(keys))
            } else {
                Err("builtins.attrNames: expected attribute set".to_string())
            }
        }
        "attrValues" => {
            if let Some(Value::Attrs(attrs)) = args.first() {
                let vals: Vec<Value> = attrs.values().cloned().collect();
                Ok(Value::List(vals))
            } else {
                Err("builtins.attrValues: expected attribute set".to_string())
            }
        }
        "hasAttr" => {
            if args.len() >= 2 {
                if let (Value::Str(key), Value::Attrs(attrs)) = (&args[0], &args[1]) {
                    Ok(Value::Bool(attrs.contains_key(key)))
                } else {
                    Err("builtins.hasAttr: invalid arguments".to_string())
                }
            } else {
                Err("builtins.hasAttr requires 2 arguments".to_string())
            }
        }
        "stringLength" => {
            if let Some(Value::Str(s)) = args.first() {
                Ok(Value::Int(s.len() as i64))
            } else {
                Err("builtins.stringLength: expected string".to_string())
            }
        }
        "substring" => {
            if args.len() >= 3 {
                if let (Value::Int(start), Value::Int(len), Value::Str(s)) = (&args[0], &args[1], &args[2]) {
                    let st = (*start).max(0) as usize;
                    let l = (*len).max(0) as usize;
                    let chars: Vec<char> = s.chars().collect();
                    if st >= chars.len() {
                        Ok(Value::Str("".to_string()))
                    } else {
                        let end = (st + l).min(chars.len());
                        let sub: String = chars[st..end].iter().collect();
                        Ok(Value::Str(sub))
                    }
                } else {
                    Err("builtins.substring: invalid arguments".to_string())
                }
            } else {
                Err("builtins.substring requires 3 arguments".to_string())
            }
        }
        "concatStringsSep" => {
            if args.len() >= 2 {
                if let (Value::Str(sep), Value::List(l)) = (&args[0], &args[1]) {
                    let mut parts = Vec::new();
                    for item in l {
                        if let Value::Str(s) = item {
                            parts.push(s.as_str());
                        } else {
                            return Err("builtins.concatStringsSep: list element is not a string".to_string());
                        }
                    }
                    Ok(Value::Str(parts.join(sep)))
                } else {
                    Err("builtins.concatStringsSep: invalid arguments".to_string())
                }
            } else {
                Err("builtins.concatStringsSep requires 2 arguments".to_string())
            }
        }
        "isAttrs" => Ok(Value::Bool(matches!(args.first(), Some(Value::Attrs(_))))),
        "isList" => Ok(Value::Bool(matches!(args.first(), Some(Value::List(_))))),
        "isString" => Ok(Value::Bool(matches!(args.first(), Some(Value::Str(_))))),
        "isInt" => Ok(Value::Bool(matches!(args.first(), Some(Value::Int(_))))),
        "isBool" => Ok(Value::Bool(matches!(args.first(), Some(Value::Bool(_))))),
        "isFunction" => Ok(Value::Bool(matches!(args.first(), Some(Value::Lambda { .. }) | Some(Value::Builtin { .. })))),
        "typeOf" => {
            if let Some(val) = args.first() {
                Ok(Value::Str(val.type_of().to_string()))
            } else {
                Err("builtins.typeOf requires 1 argument".to_string())
            }
        }
        "toString" => {
            if let Some(val) = args.first() {
                match val {
                    Value::Int(n) => Ok(Value::Str(n.to_string())),
                    Value::Str(s) => Ok(Value::Str(s.clone())),
                    Value::Bool(b) => Ok(Value::Str(b.to_string())),
                    _ => Ok(Value::Str(val.to_string_repr())),
                }
            } else {
                Err("builtins.toString requires 1 argument".to_string())
            }
        }
        _ => Err(format!("Unknown or unhandled builtin: {}", name)),
    }
}

pub fn make_builtins_set() -> BTreeMap<String, Value> {
    let mut map = BTreeMap::new();
    let builtins = [
        "length", "elemAt", "head", "tail", "attrNames", "attrValues",
        "hasAttr", "stringLength", "substring", "concatStringsSep",
        "isAttrs", "isList", "isString", "isInt", "isBool", "isFunction",
        "typeOf", "toString",
    ];
    for b in builtins {
        map.insert(
            b.to_string(),
            Value::Builtin {
                name: b.to_string(),
                arity: builtin_arity(b),
                args: Vec::new(),
            },
        );
    }
    map
}
