# Praxis Declarative Infrastructure Hypervisor
# System Module: Host & MicroVM Security Hardening
#
# Declares Seccomp-BPF system call filtering profiles, Linux Capabilities
# bounding sets, Landlock sandbox rules, and kernel lockdown modes.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.system.security = {
    seccomp = {
      enable = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enforce strict Seccomp-BPF system call filtering.";
      };

      defaultAction = lib.mkOption {
        type = types.enum [ "SCMP_ACT_ERRNO" "SCMP_ACT_KILL" "SCMP_ACT_TRAP" "SCMP_ACT_ALLOW" ];
        default = "SCMP_ACT_ERRNO";
        description = "Default action when an unlisted system call is invoked.";
      };

      allowedSyscalls = lib.mkOption {
        type = types.listOf types.str;
        default = [
          "read" "write" "openat" "close" "fstat" "lseek" "mmap" "mprotect"
          "munmap" "brk" "rt_sigaction" "rt_sigprocmask" "rt_sigreturn"
          "ioctl" "pread64" "pwrite64" "readv" "writev" "access" "pipe2"
          "select" "sched_yield" "mremap" "msync" "mincore" "madvise"
          "nanosleep" "getpid" "socket" "connect" "accept4" "sendto" "recvfrom"
          "epoll_create1" "epoll_ctl" "epoll_wait" "futex" "set_robust_list"
          "get_robust_list" "eventfd2" "clock_gettime" "clock_nanosleep"
          "exit" "exit_group"
        ];
        description = "Explicitly permitted system calls in production profile.";
      };
    };

    capabilities = {
      dropAll = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to drop all capabilities from the bounding set by default.";
      };

      retain = lib.mkOption {
        type = types.listOf types.str;
        default = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
        description = "Explicit Linux capabilities retained in ambient/permitted set.";
      };
    };

    lockdown = lib.mkOption {
      type = types.enum [ "none" "integrity" "confidentiality" ];
      default = "confidentiality";
      description = "Linux kernel lockdown mode. 'confidentiality' blocks raw MMIO, /dev/mem, and kprobes.";
    };
  };
}
