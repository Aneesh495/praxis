# Praxis Pure Nix Test Suite: Semantic Versioning 2.0 Engine

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  semver = lib.semver;

in
runner.runSuite "semver" [
  (runner.testCase "parse_standard_semver" (_:
    let
      v = semver.parse "1.2.3";
    in
    v.valid && v.major == 1 && v.minor == 2 && v.patch == 3 &&
    v.prerelease == []
  ))

  (runner.testCase "parse_prerelease_and_build" (_:
    let
      v = semver.parse "2.0.0-rc.1+build.42";
    in
    v.valid && v.major == 2 && v.minor == 0 && v.patch == 0 &&
    v.prerelease == [ "rc" "1" ] &&
    v.build == [ "build" "42" ]
  ))

  (runner.testCase "version_ordering_precedence" (_:
    semver.lt "1.0.0" "2.0.0" &&
    semver.lt "1.2.0" "1.3.0" &&
    semver.lt "1.2.3" "1.2.4" &&
    semver.lt "1.0.0-alpha" "1.0.0" && # Normal version > prerelease
    semver.eq "1.2.3" "1.2.3" &&
    semver.gt "2.0.1" "2.0.0"
  ))

  (runner.testCase "semver_caret_constraint" (_:
    # ^1.2.3 allows >= 1.2.3 and < 2.0.0
    semver.satisfies "1.2.3" "^1.2.3" &&
    semver.satisfies "1.9.0" "^1.2.3" &&
    !semver.satisfies "2.0.0" "^1.2.3" &&
    !semver.satisfies "1.2.2" "^1.2.3"
  ))

  (runner.testCase "semver_tilde_constraint" (_:
    # ~1.2.3 allows >= 1.2.3 and < 1.3.0
    semver.satisfies "1.2.3" "~1.2.3" &&
    semver.satisfies "1.2.9" "~1.2.3" &&
    !semver.satisfies "1.3.0" "~1.2.3"
  ))
]
