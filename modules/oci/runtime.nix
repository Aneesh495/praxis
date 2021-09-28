# Praxis Declarative Infrastructure Hypervisor
# OCI Module: Runtime Specification v1.0 (config.json) Generator
#
# Generates OCI runtime specification config.json files for container runtimes
# (runc, crun, youki). Configures namespaces, rootfs mounts, Linux capabilities,
# and cgroups v2 controller parameters.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.oci.runtime = {
    ociVersion = lib.mkOption {
      type = types.str;
      default = "1.0.2-dev";
      description = "OCI Runtime Specification version string.";
    };

    namespaces = lib.mkOption {
      type = types.listOf types.str;
      default = [ "pid" "network" "ipc" "uts" "mount" ];
      description = "Linux kernel namespaces unshared for the container process.";
    };

    readonlyRootfs = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Mount container root filesystem as strictly read-only.";
    };

    standardMounts = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          destination = lib.mkOption { type = types.str; description = "Container mount destination path."; };
          type = lib.mkOption { type = types.str; description = "Mount filesystem type."; };
          source = lib.mkOption { type = types.str; description = "Host source device or path."; };
          options = lib.mkOption { type = types.listOf types.str; default = []; description = "Mount options."; };
        };
      });
      default = [
        { destination = "/proc"; type = "proc"; source = "proc"; options = [ "nosuid" "noexec" "nodev" ]; }
        { destination = "/dev"; type = "tmpfs"; source = "tmpfs"; options = [ "nosuid" "strictatime" "mode=755" "size=65536k" ]; }
        { destination = "/dev/pts"; type = "devpts"; source = "devpts"; options = [ "nosuid" "noexec" "newinstance" "ptmxmode=0666" "mode=0620" ]; }
        { destination = "/dev/shm"; type = "tmpfs"; source = "shm"; options = [ "nosuid" "noexec" "nodev" "mode=1777" "size=65536k" ]; }
        { destination = "/sys"; type = "sysfs"; source = "sysfs"; options = [ "nosuid" "noexec" "nodev" "ro" ]; }
      ];
      description = "Standard virtual filesystem mounts inside the container.";
    };
  };
}
