# Praxis Declarative Infrastructure Hypervisor
# Network Module: Mutual TLS (mTLS) Public Key Infrastructure (PKI)
#
# Declares deterministic cryptographic certificate hierarchies, Root CAs,
# intermediate issuing CAs, Subject Alternative Names (SAN), and key types
# for end-to-end zero-trust transport encryption across microVM nodes.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.network.pki = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to provision declarative mTLS certificate authority hierarchies.";
    };

    algorithm = lib.mkOption {
      type = types.enum [ "ed25519" "ecdsa-p256" "rsa-4096" ];
      default = "ed25519";
      description = "Asymmetric cryptographic key algorithm.";
    };

    rootCA = {
      commonName = lib.mkOption {
        type = types.str;
        default = "Praxis Sovereign Root CA";
        description = "Common Name (CN) for the trust anchor root certificate.";
      };

      validityDays = lib.mkOption {
        type = types.int;
        default = 3650;
        description = "Root CA certificate validity duration in days.";
      };
    };

    certificates = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          commonName = lib.mkOption {
            type = types.str;
            description = "Certificate common name identifier.";
          };

          sanDNS = lib.mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of Subject Alternative Name (SAN) DNS hostnames.";
          };

          sanIP = lib.mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of Subject Alternative Name (SAN) IP addresses.";
          };

          validityDays = lib.mkOption {
            type = types.int;
            default = 365;
            description = "Leaf certificate validity period in days.";
          };

          isServer = lib.mkOption {
            type = types.bool;
            default = true;
            description = "Whether certificate is authorized for TLS server authentication.";
          };

          isClient = lib.mkOption {
            type = types.bool;
            default = true;
            description = "Whether certificate is authorized for TLS client authentication.";
          };
        };
      });
      default = {};
      description = "Declarative leaf certificate definitions.";
    };
  };
}
