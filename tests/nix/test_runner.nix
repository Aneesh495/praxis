# Praxis Pure Nix Test Framework
# Unit, Structural, and Property Test Runner
#
# Provides assertion macros, test case execution harnesses, and test suite
# aggregators in pure Nix.

let
  lib = import ../../lib {};

rec {
  # Constructs a single test case
  # name: human readable test name
  # testFn: zero-argument function returning boolean (true = pass, false = fail)
  testCase = name: testFn: {
    inherit name;
    run =
      let
        passed = testFn ();
      in
      {
        inherit name passed;
        status = if passed then "PASS" else "FAIL";
      };
  };

  # Constructs an assertion comparing expected and actual values
  assertEqual = expected: actual: expected == actual;

  # Constructs an assertion testing a boolean predicate
  assertTrue = condition: condition == true;

  # Constructs an assertion testing a boolean predicate is false
  assertFalse = condition: condition == false;

  # Runs a collection of test cases and aggregates results
  runSuite = suiteName: tests:
    let
      results = builtins.map (t: t.run) tests;
      passedCount = builtins.length (builtins.filter (r: r.passed) results);
      failedCount = builtins.length (builtins.filter (r: !r.passed) results);
      allPassed = failedCount == 0;
    in
    {
      name = suiteName;
      total = builtins.length tests;
      passed = passedCount;
      failed = failedCount;
      success = allPassed;
      inherit results;
    };
}
