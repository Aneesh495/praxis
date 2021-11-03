# Praxis Declarative Infrastructure Hypervisor
# Production Topologies Suite Root
#
# Exports pre-configured, production-grade infrastructure blueprints
# spanning low-latency colocation, global sovereign clouds, and confidential enclaves.

{ lib ? import ../lib {}, modules ? import ../modules { inherit lib; } }:

{
  hftColocation = import ./hft_colocation.nix { inherit lib modules; };
  sovereignCloud = import ./sovereign_cloud.nix { inherit lib modules; };
  secureEnclave = import ./secure_enclave.nix { inherit lib modules; };
}
