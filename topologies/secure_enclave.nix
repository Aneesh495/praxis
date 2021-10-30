# Praxis Production Blueprint
# Topology: Air-Gapped Confidential Computing MicroVM Enclave
#
# Configures an air-gapped confidential microVM enclave with hardware
# memory encryption (AMD SEV-SNP / Intel TDX), LUKS2 encrypted storage,
# Firecracker jailer containment, strict Seccomp-BPF filters, and zero egress.

{ lib ? import ../lib {}, modules ? import ../modules { inherit lib; } }:

lib.evalModules {
  modules = [
    modules.system
    modules.microvm
    modules.oci
    modules.network
    modules.cluster
    modules.database

    ({ config, ... }: {
      praxis = {
        system = {
          kernel = {
            cmdline = [
              "console=ttyS0"
              "lockdown=confidentiality"
              "random.trust_cpu=off"
              "slab_nomerge"
              "slub_debug=FZP"
              "page_poison=1"
              "pti=on"
              "nomodules"
              "quiet"
            ];
          };

          storage = {
            disks = {
              "enclave-disk" = {
                device = "/dev/vda";
                sizeMB = 8192;
                tableType = "gpt";
                partitions = [
                  {
                    name = "enclave-root";
                    sizeMB = 0; # Full disk
                    fsType = "luks2";
                    encrypted = true;
                    mountPoint = "/";
                    readOnly = true;
                  }
                ];
              };
            };
          };

          security = {
            lockdown = "confidentiality";
            seccomp = {
              enable = true;
              defaultAction = "SCMP_ACT_KILL"; # Immediately terminate process on unknown syscall
              allowedSyscalls = [
                "read" "write" "openat" "close" "fstat" "mmap" "mprotect" "munmap"
                "brk" "rt_sigaction" "rt_sigprocmask" "rt_sigreturn" "exit" "exit_group"
              ];
            };
            capabilities.dropAll = true;
          };
        };

        microvm = {
          enable = true;
          hypervisor = "firecracker";
          memory = {
            sizeMB = 8192;
            confidentialComputing = "sev-snp";
            balloon.enable = false;
          };
          jailer = {
            enable = true;
            id = "enclave-isolated-0";
            uid = 5000;
            gid = 5000;
            chrootBaseDir = "/srv/jailer/enclaves";
          };
          devices = {
            # Zero network interfaces attached: completely air-gapped
            networkInterfaces = [];
            drives = [
              {
                driveId = "encrypted-root";
                pathOnHost = "/var/lib/praxis/enclaves/root.luks2";
                isReadOnly = true;
                isRootDevice = true;
                directIo = true;
              }
            ];
            # Only point-to-point hardware vsock enabled for encrypted guest-host IPC
            vsock = {
              enable = true;
              guestCid = 42;
              udsPath = "/run/praxis/enclaves/vsock.sock";
            };
          };
        };

        network = {
          # Network completely disabled for air-gap guarantee
          wireguard.enable = false;
          ebpf.enable = false;
          ingress.enable = false;
        };
      };
    })
  ];
}
