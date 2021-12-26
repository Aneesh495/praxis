# Praxis Pure Nix Test Suite: SLSA Level 3/4 Provenance Attestation

let
  lib = import ../../lib {};
  modules = import ../../modules { inherit lib; };
  runner = import ./test_runner.nix;
  slsa = modules.provenance.slsa;

in
runner.runSuite "slsa" [
  (runner.testCase "generate_valid_in_toto_statement" (_:
    let
      doc = slsa.makeSlsaStatement {
        artifactName = "praxis-kernel.bin";
        artifactSha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
        sourceCommit = "dc204e201a5d59bf8338c1c2df5112be684022172";
      };
    in
    doc."_type" == "https://in-toto.io/Statement/v1" &&
    doc.predicateType == "https://slsa.dev/provenance/v1" &&
    (builtins.head doc.subject).name == "praxis-kernel.bin" &&
    doc.predicate.runDetails.metadata.reproducible == true
  ))
]
