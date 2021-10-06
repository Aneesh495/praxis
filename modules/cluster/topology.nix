# Praxis Declarative Infrastructure Hypervisor
# Cluster Module: Multi-Region Topology, Failure Domains, and Node Placement
#
# Declares sovereign multi-region clusters, availability zones, rack locality,
# failure domain constraints, and virtual node hardware assignments.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.cluster.topology = {
    clusterName = lib.mkOption {
      type = types.str;
      default = "praxis-global";
      description = "Globally unique cluster fabric identifier.";
    };

    regions = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          location = lib.mkOption { type = types.str; description = "Geographic region description (e.g. us-east, eu-central)."; };
          zones = lib.mkOption { type = types.listOf types.str; default = [ "a" "b" "c" ]; description = "Availability zone identifiers."; };
        };
      });
      default = {
        "us-east" = { location = "North Virginia"; zones = [ "a" "b" "c" ]; };
      };
      description = "Geographic regions comprising the distributed cluster.";
    };

    nodes = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          region = lib.mkOption { type = types.str; description = "Assigned cluster region."; };
          zone = lib.mkOption { type = types.str; default = "a"; description = "Assigned availability zone."; };
          rack = lib.mkOption { type = types.str; default = "rack-1"; description = "Failure domain rack identifier."; };
          overlayIP = lib.mkOption { type = types.ipv4; description = "Fixed WireGuard overlay IP address."; };
          roles = lib.mkOption {
            type = types.listOf (types.enum [ "control-plane" "compute" "gateway" "storage" ]);
            default = [ "compute" ];
            description = "Functional node roles in the distributed mesh.";
          };
        };
      });
      default = {};
      description = "Cluster node membership declarations.";
    };
  };
}
