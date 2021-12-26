# Praxis Pure Nix Test Suite: CVE Security Advisory Matching

let
  lib = import ../../lib {};
  modules = import ../../modules { inherit lib; };
  runner = import ./test_runner.nix;
  cve = modules.provenance.cve;

in
runner.runSuite "cve" [
  (runner.testCase "match_vulnerable_version" (_:
    let
      packages = [
        { name = "openssl"; version = "3.0.1"; }
        { name = "curl"; version = "8.4.0"; }
      ];
      advisories = [
        {
          id = "CVE-2023-0286";
          package = "openssl";
          affected = "< 3.0.8";
          severity = "CRITICAL";
          cvss = 9.8;
        }
      ];
      matches = cve.scanPackages packages advisories;
    in
    builtins.length matches == 1 &&
    (builtins.head matches).cveId == "CVE-2023-0286"
  ))

  (runner.testCase "clean_package_closure" (_:
    let
      packages = [
        { name = "openssl"; version = "3.1.2"; }
      ];
      advisories = [
        {
          id = "CVE-2023-0286";
          package = "openssl";
          affected = "< 3.0.8";
          severity = "CRITICAL";
          cvss = 9.8;
        }
      ];
      matches = cve.scanPackages packages advisories;
    in
    matches == []
  ))
]
