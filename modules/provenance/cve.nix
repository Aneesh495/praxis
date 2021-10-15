# Praxis Declarative Infrastructure Hypervisor
# Provenance Module: CVE Advisory Scanner and SemVer Matcher
#
# Audits package derivation closures against a database of CVE security advisories
# using pure Nix SemVer constraint matching. Detects vulnerable components prior
# to microVM provisioning or container image synthesis.

let
  semver = import ../../lib/semver.nix;

in
rec {
  # Evaluates whether a package version matches an advisory affected constraint
  isVulnerable = pkgVersion: constraintStr:
    semver.satisfies pkgVersion constraintStr;

  # Scans a list of resolved packages against an advisory database
  # packages: [ { name = "openssl"; version = "3.0.1"; ... } ]
  # advisories: [ { id = "CVE-2023-0286"; package = "openssl"; affected = "< 3.0.8"; severity = "CRITICAL"; cvss = 9.8; } ]
  # Returns: List of detected vulnerability matches with package metadata
  scanPackages = packages: advisories:
    let
      matches = builtins.concatMap (pkg:
        let
          relevantAdvisories = builtins.filter (adv: adv.package == pkg.name) advisories;
          matchedAdvisories = builtins.filter (adv:
            isVulnerable pkg.version adv.affected
          ) relevantAdvisories;
        in
        builtins.map (adv: {
          cveId = adv.id;
          packageName = pkg.name;
          installedVersion = pkg.version;
          affectedConstraint = adv.affected;
          severity = adv.severity;
          cvss = adv.cvss;
          description = if adv ? description then adv.description else "";
        }) matchedAdvisories
      ) packages;
    in
    matches;

  # Asserts that no CRITICAL or HIGH severity CVEs are present in the package closure
  assertNoHighVulnerabilities = scanResults:
    let
      blockers = builtins.filter (m: m.severity == "CRITICAL" || m.severity == "HIGH") scanResults;
    in
    if blockers != [] then
      let
        first = builtins.head blockers;
      in
      throw "Praxis Security Blocker: ${first.packageName}@${first.installedVersion} is vulnerable to ${first.cveId} (${first.severity}, CVSS ${toString first.cvss})"
    else
      true;
}
