# Praxis Declarative Infrastructure Hypervisor
# Network Module: Routing Tables and Dijkstra Next-Hop Forwarding
#
# Declares network link topologies, link latency weights, policy-based
# routing tables, and computes shortest next-hop routes using pure Nix Dijkstra.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.network.routing = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to synthesize kernel IP route tables and next-hop forwarding rules.";
    };

    links = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          source = lib.mkOption { type = types.str; description = "Source node identifier."; };
          target = lib.mkOption { type = types.str; description = "Target node identifier."; };
          weight = lib.mkOption { type = types.int; default = 10; description = "Link metric or latency cost."; };
          interface = lib.mkOption { type = types.str; default = "wg-praxis"; description = "Egress interface name."; };
        };
      });
      default = [];
      description = "List of directed network topology edges for Dijkstra path calculation.";
    };

    staticRoutes = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          destination = lib.mkOption { type = types.cidr; description = "Destination CIDR prefix."; };
          gateway = lib.mkOption { type = types.ipv4; description = "Next-hop gateway IP address."; };
          interface = lib.mkOption { type = types.str; description = "Egress network interface."; };
          metric = lib.mkOption { type = types.int; default = 100; description = "Route metric priority."; };
        };
      });
      default = [];
      description = "Explicit static kernel routes.";
    };
  };
}
