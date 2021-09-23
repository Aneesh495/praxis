# Praxis Declarative Infrastructure Hypervisor
# MicroVM Module: Hypervisor Target Abstraction
#
# Declares microVM hypervisor target engines (Firecracker, Cloud-Hypervisor, QEMU-KVM),
# binary paths, socket endpoints, and control plane lifecycle hooks.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.microvm = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to synthesize and provision microVM instances.";
    };

    hypervisor = lib.mkOption {
      type = types.enum [ "firecracker" "cloud-hypervisor" "qemu" ];
      default = "firecracker";
      description = "MicroVM virtual machine monitor (VMM) backend.";
    };

    socketPath = lib.mkOption {
      type = types.str;
      default = "/run/praxis/microvm.sock";
      description = "Unix domain control socket path for VMM API communication.";
    };

    logLevel = lib.mkOption {
      type = types.enum [ "Error" "Warning" "Info" "Debug" ];
      default = "Info";
      description = "VMM hypervisor internal logging verbosity level.";
    };

    kernelImage = lib.mkOption {
      type = types.str;
      default = "/var/lib/praxis/vmlinux.bin";
      description = "Path to uncompressed ELF vmlinux kernel image.";
    };
  };
}
