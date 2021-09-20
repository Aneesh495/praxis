# Praxis Declarative Infrastructure Hypervisor
# System Module: Storage, Partition Tables, and Encryption
#
# Declares disk partition topologies, GUID Partition Tables (GPT),
# LUKS2 cryptographic headers, filesystem types, and mount points.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.system.storage = {
    disks = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          device = lib.mkOption {
            type = types.str;
            description = "Target block device path (e.g. /dev/vda).";
          };

          sizeMB = lib.mkOption {
            type = types.int;
            default = 10240;
            description = "Disk image capacity in megabytes.";
          };

          tableType = lib.mkOption {
            type = types.enum [ "gpt" "mbr" ];
            default = "gpt";
            description = "Disk partition table format.";
          };

          partitions = lib.mkOption {
            type = types.listOf (types.submodule {
              options = {
                name = lib.mkOption {
                  type = types.str;
                  description = "Partition label name.";
                };

                sizeMB = lib.mkOption {
                  type = types.int;
                  description = "Partition size in megabytes (0 for remainder of disk).";
                };

                fsType = lib.mkOption {
                  type = types.enum [ "ext4" "squashfs" "xfs" "vfat" "swap" "luks2" ];
                  default = "ext4";
                  description = "Filesystem formatting type.";
                };

                mountPoint = lib.mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Target directory mountpoint (e.g. /, /var/data).";
                };

                readOnly = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether filesystem should be mounted read-only.";
                };

                encrypted = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether partition is protected via LUKS2 encryption.";
                };
              };
            });
            default = [];
            description = "List of ordered partition declarations.";
          };
        };
      });
      default = {};
      description = "Declarative storage disk mappings.";
    };
  };
}
