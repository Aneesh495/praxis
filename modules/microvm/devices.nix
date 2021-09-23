# Praxis Declarative Infrastructure Hypervisor
# MicroVM Module: Virtio Device Attachments and Vsock Channels
#
# Declares virtio-blk block storage devices, virtio-net network interfaces,
# virtio-fs shared directory trees, and vsock point-to-point sockets.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.microvm.devices = {
    networkInterfaces = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          id = lib.mkOption {
            type = types.str;
            description = "Unique device identifier for the network interface.";
          };

          hostDevName = lib.mkOption {
            type = types.str;
            description = "Host TAP or MACVTAP interface name (e.g. tap0).";
          };

          guestMac = lib.mkOption {
            type = types.str;
            default = "02:fc:00:00:00:01";
            description = "Hardware MAC address exposed to the guest.";
          };

          rxRateLimiter = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Inbound bandwidth rate limiter in bytes per second.";
          };

          txRateLimiter = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Outbound bandwidth rate limiter in bytes per second.";
          };
        };
      });
      default = [];
      description = "List of virtio-net device attachments.";
    };

    drives = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          driveId = lib.mkOption {
            type = types.str;
            description = "Unique drive identifier name.";
          };

          pathOnHost = lib.mkOption {
            type = types.str;
            description = "Path to backing file or raw block device on the host.";
          };

          isReadOnly = lib.mkOption {
            type = types.bool;
            default = false;
            description = "Whether the attached drive is read-only.";
          };

          isRootDevice = lib.mkOption {
            type = types.bool;
            default = false;
            description = "Whether this drive represents the root filesystem /dev/vda.";
          };

          directIo = lib.mkOption {
            type = types.bool;
            default = true;
            description = "Bypass host page cache using O_DIRECT flags.";
          };
        };
      });
      default = [];
      description = "List of virtio-blk storage drive attachments.";
    };

    vsock = {
      enable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to attach a virtio-vsock device for guest-host IPC.";
      };

      guestCid = lib.mkOption {
        type = types.int;
        default = 3;
        description = "Context Identifier (CID) assigned to guest vsock endpoint.";
      };

      udsPath = lib.mkOption {
        type = types.str;
        default = "/run/praxis/vsock.sock";
        description = "Host Unix domain socket multiplexing vsock channels.";
      };
    };
  };
}
