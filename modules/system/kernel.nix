# Praxis Declarative Infrastructure Hypervisor
# System Module: Linux Kernel, Command Line, and Sysctl Subsystem
#
# Declares kernel configuration parameters, boot cmdline parameters,
# sysctl runtime tunables, and out-of-tree kernel module requirements.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.system.kernel = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to manage kernel parameters and sysctl tunables.";
    };

    version = lib.mkOption {
      type = types.str;
      default = "6.6.28";
      description = "Target Linux LTS kernel version.";
    };

    architecture = lib.mkOption {
      type = types.enum [ "x86_64" "aarch64" "riscv64" ];
      default = "x86_64";
      description = "Target CPU processor architecture.";
    };

    cmdline = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "console=ttyS0"
        "reboot=k"
        "panic=1"
        "pci=off"
        "nomodules"
        "quiet"
        "loglevel=3"
      ];
      description = "List of kernel boot command-line arguments.";
    };

    sysctl = lib.mkOption {
      type = types.attrsOf types.str;
      default = {
        "net.ipv4.ip_forward" = "1";
        "net.ipv4.conf.all.rp_filter" = "1";
        "net.ipv4.conf.default.rp_filter" = "1";
        "net.ipv4.tcp_syncookies" = "1";
        "net.core.bpf_jit_enable" = "1";
        "net.core.bpf_jit_harden" = "2";
        "kernel.unprivileged_bpf_disabled" = "1";
        "kernel.kptr_restrict" = "2";
        "kernel.dmesg_restrict" = "1";
        "vm.swappiness" = "0";
        "vm.panic_on_oom" = "0";
        "fs.file-max" = "2097152";
      };
      description = "Kernel sysctl runtime configuration key-value mappings.";
    };

    extraModules = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional kernel driver modules to load on boot.";
    };
  };

  config = lib.mkIf false {}; # Config is computed at system evaluation
}
