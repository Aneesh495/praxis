# Praxis Declarative Infrastructure Hypervisor
# Network Module: Split-Horizon DNS and Service Discovery Zones
#
# Generates RFC 1035 compliant DNS zone files and CoreDNS/Unbound configurations
# directly from declared cluster topology nodes, services, and overlay VIPs.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.network.dns = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to synthesize split-horizon internal DNS zone files.";
    };

    domain = lib.mkOption {
      type = types.str;
      default = "praxis.internal";
      description = "Internal top-level domain for cluster service discovery.";
    };

    ttl = lib.mkOption {
      type = types.int;
      default = 60;
      description = "Default DNS record Time-To-Live (TTL) in seconds.";
    };

    upstreamServers = lib.mkOption {
      type = types.listOf types.ipv4;
      default = [ "1.1.1.1" "8.8.8.8" ];
      description = "Upstream recursive resolvers for external internet domain lookups.";
    };

    records = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          type = lib.mkOption {
            type = types.enum [ "A" "AAAA" "CNAME" "TXT" "SRV" ];
            default = "A";
            description = "DNS resource record type.";
          };

          value = lib.mkOption {
            type = types.str;
            description = "Target IP address, hostname, or record text.";
          };
        };
      });
      default = {};
      description = "Static internal DNS records mapping name to target value.";
    };
  };
}
