# Praxis Declarative Infrastructure Hypervisor
# System Module: Boot Subsystem, Initramfs, and Pivot Root
#
# Declares early boot parameters, initramfs image configuration,
# early rootfs device mounting, and switch_root targets.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.system.boot = {
    loader = lib.mkOption {
      type = types.enum [ "direct-kernel" "systemd-boot" "grub" "none" ];
      default = "direct-kernel";
      description = "Bootloader execution mechanism. 'direct-kernel' is preferred for microVMs.";
    };

    initramfs = {
      enable = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to synthesize and bundle an early initramfs ramdisk.";
      };

      compression = lib.mkOption {
        type = types.enum [ "zstd" "gzip" "lz4" "none" ];
        default = "zstd";
        description = "Compression algorithm for synthesized initramfs archive.";
      };

      earlyModules = lib.mkOption {
        type = types.listOf types.str;
        default = [ "virtio_pci" "virtio_blk" "virtio_net" "ext4" "squashfs" ];
        description = "Kernel drivers required inside initramfs for rootfs discovery.";
      };
    };

    rootDevice = lib.mkOption {
      type = types.str;
      default = "/dev/vda";
      description = "Block device path or UUID containing the root filesystem.";
    };

    rootFsType = lib.mkOption {
      type = types.enum [ "ext4" "squashfs" "btrfs" "erofs" ];
      default = "ext4";
      description = "Filesystem type of the root device.";
    };

    initPath = lib.mkOption {
      type = types.str;
      default = "/sbin/init";
      description = "Path to real init executable inside rootfs target.";
    };
  };
}
