# Praxis Declarative Infrastructure Hypervisor
# Provenance Module: CycloneDX 1.5 and SPDX 3.0 SBOM Generator
#
# Synthesizes industry-standard Software Bill of Materials (SBOM) in CycloneDX 1.5
# and SPDX formats directly from Nix derivation dependency closures in pure Nix.

let
  uuid = import ../../lib/uuid.nix;

in
rec {
  # Synthesizes CycloneDX 1.5 JSON SBOM document
  # rootComponent: { name, version, type, description }
  # packages: List of { name, version, sha256, purl, license, dependencies }
  makeCycloneDxSbom = {
    rootComponent,
    packages ? [],
    timestamp ? "1970-01-01T00:00:01Z",
  }: {
    bomFormat = "CycloneDX";
    specVersion = "1.5";
    serialNumber = "urn:uuid:" + (uuid.uuidv5 uuid.namespaces.dns ("praxis-sbom-" + rootComponent.name + "-" + rootComponent.version));
    version = 1;
    metadata = {
      inherit timestamp;
      tools = [
        {
          vendor = "Praxis";
          name = "praxis-sbom-generator";
          version = "0.1.0";
        }
      ];
      component = {
        name = rootComponent.name;
        version = rootComponent.version;
        type = if rootComponent ? type then rootComponent.type else "application";
        description = if rootComponent ? description then rootComponent.description else "";
      };
    };
    components = builtins.map (pkg: {
      type = "library";
      name = pkg.name;
      version = pkg.version;
      purl = if pkg ? purl then pkg.purl else "pkg:generic/${pkg.name}@${pkg.version}";
      hashes = [
        {
          alg = "SHA-256";
          content = pkg.sha256;
        }
      ];
      licenses = if pkg ? license then [ { license = { id = pkg.license; }; } ] else [];
    }) packages;
    dependencies = builtins.map (pkg: {
      ref = "pkg:generic/${pkg.name}@${pkg.version}";
      dependsOn = if pkg ? dependencies then pkg.dependencies else [];
    }) packages;
  };
}
