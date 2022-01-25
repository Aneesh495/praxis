# Praxis Software Supply Chain Security

Praxis provides end-to-end cryptographic supply chain security (`modules/provenance/`), generating SLSA Level 4 in-toto provenance statements, CycloneDX 1.5 Software Bill of Materials (SBOM) records, and automated NIST CVE vulnerability assertions directly from evaluated build graphs.

```
+========================================================================================+
|                              SUPPLY CHAIN ASSURANCE PIPELINE                           |
+========================================================================================+
|                                                                                        |
|   +--------------------------------------------------------------------------------+   |
|   |                          HERMETIC BUILD ENVIRONMENT                            |   |
|   |   - Fixed-output derivations with bit-for-bit reproducible outputs             |   |
|   |   - Zero network access during compilation; isolated sandbox namespaces        |   |
|   +---------------------------------------+----------------------------------------+   |
|                                           |                                            |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                        IN-TOTO SLSA LEVEL 4 PROVENANCE                         |   |
|   |   - Cryptographic subject digests (SHA-256 calculated in pure Nix)             |   |
|   |   - Build definition parameters, entrypoint, compiler toolchain provenance     |   |
|   |   - Cryptographically verifiable cosign / in-toto signature envelopes          |   |
|   +---------------------------------------+----------------------------------------+   |
|                                           |                                            |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                        CYCLONEDX 1.5 SBOM MANIFEST                             |   |
|   |   - Full transitive dependency tree with standard Package URLs (purl)          |   |
|   |   - SPDX 3.0 license identifiers and component cryptographic hashes            |   |
|   +---------------------------------------+----------------------------------------+   |
|                                           |                                            |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                       CVE VULNERABILITY ADVISORY GATE                          |   |
|   |   - Automated scan against NIST National Vulnerability Database (NVD) feeds    |   |
|   |   - CVSS v3.1 severity threshold gate (Aborts on unmitigated High/Critical)    |   |
|   +--------------------------------------------------------------------------------+   |
+========================================================================================+
```

---

## 1. SLSA Level 4 Provenance Generation

Praxis synthesizes in-toto v1.0 provenance attestations matching the highest SLSA security tier (SLSA Level 4):

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [
    {
      "name": "praxis-hypervisor-rootfs",
      "digest": {
        "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      }
    }
  ],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://praxis.systems/build/nix/v1",
      "externalParameters": {
        "source": "git+https://github.com/Aneesh495/praxis.git",
        "entrypoint": "flake.nix#packages.x86_64-linux.default"
      },
      "internalParameters": {
        "isolated": true,
        "hermetic": true
      },
      "resolvedDependencies": [
        {
          "uri": "pkg:nix/nixpkgs@23.11?commit=a8b3f1c...",
          "digest": {
            "sha256": "4a5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c"
          }
        }
      ]
    },
    "runDetails": {
      "builder": {
        "id": "https://praxis.systems/builders/hermetic-evaluator-v1"
      },
      "metadata": {
        "invocationId": "urn:uuid:f47ac10b-58cc-4372-a567-0e02b2c3d479"
      }
    }
  }
}
```

---

## 2. CycloneDX 1.5 Software Bill of Materials (SBOM)

Every compiled Praxis artifact is accompanied by a standardized CycloneDX 1.5 JSON SBOM manifest detailing every compiled binary, kernel object, and shared library:

- **Format Compliance**: CycloneDX 1.5 Specification with schema validation.
- **Transitive Closure**: Traverses the Nix derivation dependency tree to capture all build and runtime dependencies.
- **PURL Formatting**: Encodes package coordinates into standard Package URLs (`pkg:nix/glibc@2.38`, `pkg:cargo/praxis_core@0.1.0`).
- **License Compliance**: Validates SPDX license identifiers (`MIT`, `Apache-2.0`, `GPL-2.0-only`), detecting incompatible license combinations before release.

---

## 3. Automated CVE Vulnerability Gate

The Praxis evaluator inspects declared package dependencies against vulnerability advisory databases:
- Filters component packages by version and package URL.
- Matches reported Common Vulnerabilities and Exposures (CVEs) with CVSS v3.1 base metrics.
- Rejection policy: If a dependency is matched against a known vulnerability rated High (CVSS $\ge 7.0$) or Critical (CVSS $\ge 9.0$) without an explicit documented waiver, evaluation halts with a fatal assertion error.
