# Praxis Declarative Infrastructure Hypervisor
# MicroVM Module: vCPU Topology and CPU Pinning
#
# Declares virtual CPU counts, simultaneous multithreading (SMT) settings,
# host CPU core pinning (isolcpus), and NUMA node memory affinity.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.microvm.vcpu = {
    count = lib.mkOption {
      type = types.int;
      default = 2;
      description = "Number of virtual CPUs exposed to the guest microVM.";
    };

    smt = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable simultaneous multithreading (hyperthreading) on vCPUs.";
    };

    pinning = lib.mkOption {
      type = types.listOf types.int;
      default = [];
      description = "Host CPU core IDs to pin vCPUs to (e.g. [ 2 3 ] for isolcpus).";
    };

    numaNode = lib.mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Target host NUMA node ID for memory and CPU affinity allocation.";
    };
  };
}
