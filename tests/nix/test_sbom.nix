# Praxis Pure Nix Test Suite: CycloneDX 1.5 Software Bill of Materials (SBOM)

let
  lib = import ../../lib {};
  modules = import ../../modules { inherit lib; };
  runner = import ./test_runner.nix;
  sbom = modules.provenance.sbom;

in
runner.runSuite "sbom" [
  (runner.testCase "cyclonedx_document_schema" (_:
    let
      doc = sbom.makeCycloneDxSbom {
        rootComponent = {
          name = "praxis-hypervisor";
          version = "0.1.0";
          description = "Declarative Infrastructure Hypervisor";
        };
        packages = [
          {
            name = "firecracker";
            version = "1.7.0";
            sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
            license = "Apache-2.0";
          }
        ];
      };
    in
    doc.bomFormat == "CycloneDX" &&
    doc.specVersion == "1.5" &&
    doc.metadata.component.name == "praxis-hypervisor" &&
    builtins.length doc.components == 1 &&
    (builtins.head doc.components).name == "firecracker"
  ))
]
