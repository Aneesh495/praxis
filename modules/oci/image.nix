# Praxis Declarative Infrastructure Hypervisor
# OCI Module: Image Specification v1.1 Manifest and Config Synthesis
#
# Generates OCI Image Spec v1.1 compliant image manifests, config descriptors,
# entrypoints, environment variable arrays, and content-addressable layer digests
# directly in pure Nix without requiring Docker or root privileges.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.oci.image = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to synthesize deterministic OCI container images.";
    };

    architecture = lib.mkOption {
      type = types.enum [ "amd64" "arm64" "riscv64" ];
      default = "amd64";
      description = "CPU architecture recorded in OCI config blob.";
    };

    os = lib.mkOption {
      type = types.enum [ "linux" ];
      default = "linux";
      description = "Target operating system recorded in OCI config blob.";
    };

    entrypoint = lib.mkOption {
      type = types.listOf types.str;
      default = [ "/bin/sh" ];
      description = "Default container entrypoint executable array.";
    };

    cmd = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Default arguments passed to container entrypoint.";
    };

    env = lib.mkOption {
      type = types.attrsOf types.str;
      default = {
        "PATH" = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
        "SSL_CERT_FILE" = "/etc/ssl/certs/ca-certificates.crt";
      };
      description = "Environment variables injected into container runtime.";
    };

    workingDir = lib.mkOption {
      type = types.str;
      default = "/";
      description = "Current working directory inside container.";
    };

    user = lib.mkOption {
      type = types.str;
      default = "0:0";
      description = "Container execution user and group (e.g. '1000:1000').";
    };

    labels = lib.mkOption {
      type = types.attrsOf types.str;
      default = {
        "org.opencontainers.image.source" = "https://github.com/Aneesh495/praxis";
        "org.opencontainers.image.vendor" = "Praxis";
      };
      description = "Metadata labels attached to OCI image descriptor.";
    };
  };
}
