# Praxis Declarative Infrastructure Hypervisor
# Network Module: Zero-Trust WireGuard Overlay Mesh
#
# Declares encrypted WireGuard overlay networks, peer relationships,
# endpoint addresses, persistent keepalives, and allowed IP subnets.
# Generates symmetrical, bit-for-bit reproducible wireguard-tools configurations.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.network.wireguard = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to provision the WireGuard zero-trust overlay mesh.";
    };

    interfaceName = lib.mkOption {
      type = types.str;
      default = "wg-praxis";
      description = "Kernel network interface name for WireGuard.";
    };

    listenPort = lib.mkOption {
      type = types.port;
      default = 51820;
      description = "UDP port for WireGuard incoming encrypted handshakes.";
    };

    privateKeyFile = lib.mkOption {
      type = types.str;
      default = "/run/praxis/wireguard.key";
      description = "Filesystem path to the local WireGuard private key.";
    };

    topology = lib.mkOption {
      type = types.enum [ "full-mesh" "hub-and-spoke" ];
      default = "full-mesh";
      description = "Mesh routing topology structure.";
    };

    overlayCidr = lib.mkOption {
      type = types.cidr;
      default = "10.200.0.0/16";
      description = "Virtual IP subnet allocated for the WireGuard mesh.";
    };

    peers = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          publicKey = lib.mkOption {
            type = types.str;
            description = "Base64-encoded WireGuard 32-byte public key.";
          };

          endpoint = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Publicly routable IP/host and port (e.g. '198.51.100.1:51820').";
          };

          allowedIPs = lib.mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Subnets routed through this encrypted tunnel peer.";
          };

          persistentKeepalive = lib.mkOption {
            type = types.int;
            default = 25;
            description = "NAT keepalive interval in seconds (0 to disable).";
          };
        };
      });
      default = {};
      description = "Attribute set of remote WireGuard peer configurations.";
    };
  };
}
