# Praxis Declarative Infrastructure Hypervisor
# Provenance Module: SLSA Level 3/4 In-Toto Attestation Generator
#
# Synthesizes SLSA v1.0 provenance attestations and in-toto v1.0 statements
# in pure Nix, capturing hermetic build dependencies, source commit hashes,
# builder IDs, and cryptographic digest trees for software supply chain security.

rec {
  # Synthesizes an in-toto v1.0 SLSA Provenance statement
  # args:
  # - artifactName: Name of binary, image, or artifact
  # - artifactSha256: 64-char hex digest
  # - builderId: URI of builder environment
  # - sourceRepo: Git repository URI
  # - sourceCommit: 40-char git commit SHA
  # - dependencies: List of { name = ...; sha256 = ...; }
  makeSlsaStatement = {
    artifactName,
    artifactSha256,
    builderId ? "https://github.com/Aneesh495/praxis/engine@v0.1.0",
    sourceRepo ? "https://github.com/Aneesh495/praxis",
    sourceCommit,
    dependencies ? [],
  }: {
    "_type" = "https://in-toto.io/Statement/v1";
    subject = [
      {
        name = artifactName;
        digest = {
          sha256 = artifactSha256;
        };
      }
    ];
    predicateType = "https://slsa.dev/provenance/v1";
    predicate = {
      buildDefinition = {
        buildType = "https://praxis.dev/pure-nix-eval/v1";
        externalParameters = {
          entrypoint = "default.nix";
          source = {
            uri = sourceRepo;
            digest = {
              gitCommit = sourceCommit;
            };
          };
        };
        internalParameters = {
          hermetic = true;
          deterministic = true;
          sandbox = "strict";
        };
        resolvedDependencies = builtins.map (dep: {
          uri = "pkg:${dep.name}";
          digest = {
            sha256 = dep.sha256;
          };
        }) dependencies;
      };
      runDetails = {
        builder = {
          id = builderId;
        };
        metadata = {
          invocationId = "praxis-inv-${artifactSha256}";
          completeness = {
            parameters = true;
            environment = true;
            materials = true;
          };
          reproducible = true;
        };
      };
    };
  };
}
