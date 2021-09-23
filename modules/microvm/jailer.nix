# Praxis Declarative Infrastructure Hypervisor
# MicroVM Module: Firecracker Jailer Security Boundary
#
# Declares process jailer containment parameters, unprivileged UID/GID mappings,
# chroot root directories, and cgroup v2 subtree limits for hypervisor processes.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.microvm.jailer = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to launch the hypervisor under the Firecracker jailer containment boundary.";
    };

    id = lib.mkOption {
      type = types.str;
      default = "microvm-0";
      description = "Unique alphanumeric jailer instance identifier.";
    };

    uid = lib.mkOption {
      type = types.int;
      default = 2000;
      description = "Host UID mapped inside the jailer chroot container.";
    };

    gid = lib.mkOption {
      type = types.int;
      default = 2000;
      description = "Host GID mapped inside the jailer chroot container.";
    };

    chrootBaseDir = lib.mkOption {
      type = types.str;
      default = "/srv/jailer";
      description = "Base root filesystem path where the jailer constructs the isolated chroot hierarchy.";
    };

    daemonize = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether the jailer should daemonize and detach standard streams.";
    };

    cgroupVersion = lib.mkOption {
      type = types.enum [ "2" ];
      default = "2";
      description = "Cgroup hierarchy version enforced by jailer.";
    };
  };
}
