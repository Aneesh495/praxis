# Praxis Declarative Infrastructure Hypervisor
# Root Module Loader & Aggregate Schema Exporter
#
# Aggregates all declarative system, hypervisor, container, network,
# cluster, database, provenance, and multi-cloud modules into a unified suite.

{ lib ? import ../lib {} }:

let
  system = {
    imports = [
      ./system/kernel.nix
      ./system/boot.nix
      ./system/storage.nix
      ./system/security.nix
      ./system/user.nix
    ];
  };

  microvm = {
    imports = [
      ./microvm/hypervisor.nix
      ./microvm/vcpu.nix
      ./microvm/memory.nix
      ./microvm/devices.nix
      ./microvm/jailer.nix
    ];
  };

  oci = {
    imports = [
      ./oci/image.nix
      ./oci/layers.nix
      ./oci/runtime.nix
      ./oci/whiteout.nix
    ];
  };

  network = {
    imports = [
      ./network/wireguard.nix
      ./network/ebpf_firewall.nix
      ./network/pki.nix
      ./network/dns.nix
      ./network/routing.nix
      ./network/ingress.nix
    ];
  };

  cluster = {
    imports = [
      ./cluster/topology.nix
      ./cluster/raft.nix
      ./cluster/supervisor.nix
      ./cluster/telemetry.nix
    ];
  };

  database = {
    imports = [
      ./database/schema.nix
      ./database/types.nix
    ];
    diff = import ./database/diff.nix;
    codegen = import ./database/codegen.nix;
  };

  provenance = {
    slsa = import ./provenance/slsa.nix;
    sbom = import ./provenance/sbom.nix;
    cve = import ./provenance/cve.nix;
  };

  cloud = {
    terraform = import ./cloud/terraform.nix;
    cloudformation = import ./cloud/cloudformation.nix;
    k8s = import ./cloud/k8s.nix;
  };

in
{
  inherit system microvm oci network cluster database provenance cloud;

  # Aggregate module containing all subsystems for top-level system evaluation
  allModules = [
    system
    microvm
    oci
    network
    cluster
    database
  ];
}
