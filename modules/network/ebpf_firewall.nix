# Praxis Declarative Infrastructure Hypervisor
# Network Module: eBPF XDP & Traffic Control (tc) Packet Filter Synthesizer
#
# Synthesizes high-performance eBPF C programs directly from declarative firewall
# policies in pure Nix. Compiles L4 port filters, CIDR blocklists, and SYN flood
# mitigations into XDP hook bytecode for sub-microsecond packet processing.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.network.ebpf = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to synthesize and attach eBPF XDP and tc packet filters.";
    };

    hook = lib.mkOption {
      type = types.enum [ "xdp" "tc-ingress" "tc-egress" ];
      default = "xdp";
      description = "Kernel networking subsystem attachment hook.";
    };

    interface = lib.mkOption {
      type = types.str;
      default = "eth0";
      description = "Host network interface to attach eBPF filters to.";
    };

    defaultAction = lib.mkOption {
      type = types.enum [ "XDP_PASS" "XDP_DROP" ];
      default = "XDP_DROP";
      description = "Default policy action when no explicit filter rule matches.";
    };

    rules = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = lib.mkOption {
            type = types.str;
            description = "Human-readable rule name.";
          };

          protocol = lib.mkOption {
            type = types.enum [ "tcp" "udp" "icmp" "any" ];
            default = "any";
            description = "L4 transport protocol to match.";
          };

          srcCidr = lib.mkOption {
            type = types.nullOr types.cidr;
            default = null;
            description = "Source IPv4 CIDR mask to match.";
          };

          destPort = lib.mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Destination L4 port to match.";
          };

          action = lib.mkOption {
            type = types.enum [ "XDP_PASS" "XDP_DROP" ];
            default = "XDP_PASS";
            description = "Action executed when packet satisfies criteria.";
          };
        };
      });
      default = [
        { name = "allow-ssh"; protocol = "tcp"; srcCidr = null; destPort = 22; action = "XDP_PASS"; }
        { name = "allow-wireguard"; protocol = "udp"; srcCidr = null; destPort = 51820; action = "XDP_PASS"; }
        { name = "allow-https"; protocol = "tcp"; srcCidr = null; destPort = 443; action = "XDP_PASS"; }
      ];
      description = "Ordered list of packet filtering rule specifications.";
    };
  };
}
