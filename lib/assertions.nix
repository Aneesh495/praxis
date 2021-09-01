# Praxis Pure Nix Standard Library
# Assertion System and Invariant Validation
#
# Provides utilities for declaring, formatting, and verifying architectural
# invariants, resource constraints, and contract assertions across Praxis systems.

rec {
  # Constructs an assertion object.
  # assertion: boolean condition that MUST evaluate to true.
  # message: clear explanation of the invariant violated if false.
  mkAssertion = assertion: message: {
    inherit assertion message;
  };

  # Formats a failure message with diagnostic location context.
  formatFailure = loc: msg:
    let
      locStr = if builtins.isList loc then builtins.concatStringsSep "." loc else toString loc;
    in
    "Praxis Invariant Violation at [${locStr}]: ${msg}";

  # Assert that an integer port is within standard valid range (1..65535).
  assertValidPort = loc: p:
    mkAssertion
      (builtins.isInt p && p >= 1 && p <= 65535)
      (formatFailure loc "Port ${toString p} is outside valid range 1-65535");

  # Assert that CIDR mask is within valid IPv4 bounds (0..32).
  assertValidPrefix = loc: prefix:
    mkAssertion
      (builtins.isInt prefix && prefix >= 0 && prefix <= 32)
      (formatFailure loc "CIDR prefix /${toString prefix} is invalid; must be between 0 and 32");

  # Assert that a list has no duplicate elements.
  assertUnique = loc: list:
    let
      counts = builtins.foldl' (acc: item:
        let
          key = toString item;
          curr = if builtins.hasAttr key acc then acc.${key} else 0;
        in
        acc // { ${key} = curr + 1; }
      ) {} list;
      duplicates = builtins.filter (k: counts.${k} > 1) (builtins.attrNames counts);
    in
    mkAssertion
      (duplicates == [])
      (formatFailure loc "Elements must be unique; duplicates detected: [${builtins.concatStringsSep ", " duplicates}]");

  # Assert that node memory is sufficient for allocation.
  assertMemoryThreshold = loc: allocatedMB: minimumMB:
    mkAssertion
      (allocatedMB >= minimumMB)
      (formatFailure loc "Allocated memory (${toString allocatedMB} MB) is below mandatory minimum (${toString minimumMB} MB)");

  # Evaluates a list of assertions. Throws on the first failing condition.
  verifyAll = assertions:
    let
      failures = builtins.filter (a: !a.assertion) assertions;
    in
    if failures != [] then
      let
        first = builtins.head failures;
      in
      throw first.message
    else
      true;
}
