# Praxis Declarative Infrastructure Hypervisor
# MicroVM Module: RAM Allocation, Hugepages, and Memory Encryption
#
# Declares guest physical memory capacity, hugepage backing, virtio-ballooning,
# and confidential computing memory encryption extensions (AMD SEV-SNP, Intel TDX).

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.microvm.memory = {
    sizeMB = lib.mkOption {
      type = types.int;
      default = 2048;
      description = "Guest RAM capacity in megabytes.";
    };

    hugepages = lib.mkOption {
      type = types.enum [ "none" "2MB" "1GB" ];
      default = "none";
      description = "Hugepages backing allocation for guest physical RAM.";
    };

    balloon = {
      enable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to attach a virtio-balloon device for dynamic memory reclaiming.";
      };

      deflateOnOOM = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Automatically deflate balloon when host encounters memory pressure.";
      };
    };

    confidentialComputing = lib.mkOption {
      type = types.enum [ "none" "sev" "sev-es" "sev-snp" "tdx" ];
      default = "none";
      description = "Hardware-enforced confidential computing memory encryption.";
    };
  };
}
