# Praxis Production Blueprint
# Topology: High-Frequency Trading (HFT) Market Data & Execution Colocation
#
# Configures ultra-low latency Firecracker microVMs with kernel bypass,
# dedicated CPU core pinning (isolcpus), 1GB hugepages, disabled SMT,
# direct I/O virtio drives, and sub-microsecond eBPF XDP packet filtering.

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
              "isolcpus=2,3,4,5"
              "nohz_full=2,3,4,5"
              "rcu_nocbs=2,3,4,5"
              "intel_idle.max_cstate=0"
              "processor.max_cstate=0"
              "idle=poll"
              "tsc=reliable"
              "nomodules"
              "quiet"
            ];
            sysctl = {
              "net.core.busy_read" = "50";
              "net.core.busy_poll" = "50";
              "net.core.rmem_max" = "134217728";
              "net.core.wmem_max" = "134217728";
              "vm.swappiness" = "0";
              "vm.nr_hugepages" = "4"; # 4x 1GB hugepages = 4GB pinned RAM
            };
          };

          security = {
            lockdown = "confidentiality";
            capabilities.retain = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_NICE" ];
          };
        };

        microvm = {
          enable = true;
          hypervisor = "firecracker";
          vcpu = {
            count = 4;
            smt = false;
            pinning = [ 2 3 4 5 ];
            numaNode = 0;
          };
          memory = {
            sizeMB = 4096;
            hugepages = "1GB";
            balloon.enable = false; # Deterministic latency: no balloon reclamation
          };
          devices = {
            networkInterfaces = [
              {
                id = "eth-exchange";
                hostDevName = "tap-hft0";
                guestMac = "02:fc:00:aa:bb:01";
                rxRateLimiter = null;
                txRateLimiter = null;
              }
            ];
            drives = [
              {
                driveId = "rootfs";
                pathOnHost = "/var/lib/praxis/disks/hft-root.ext4";
                isReadOnly = false;
                isRootDevice = true;
                directIo = true; # Direct MMIO bypasses host page cache
              }
            ];
          };
        };

        network = {
          ebpf = {
            enable = true;
            hook = "xdp";
            interface = "eth-exchange";
            defaultAction = "XDP_DROP";
            rules = [
              # Low latency market data multicast feeds
              { name = "itch-multicast"; protocol = "udp"; srcCidr = "192.168.100.0/24"; destPort = 10001; action = "XDP_PASS"; }
              # Direct order execution binary protocol
              { name = "ouch-order-entry"; protocol = "tcp"; srcCidr = "192.168.100.0/24"; destPort = 10002; action = "XDP_PASS"; }
            ];
          };

          wireguard = {
            enable = true;
            listenPort = 51820;
            overlayCidr = "10.250.0.0/24";
            peers = {
              "ny4-gateway" = {
                publicKey = "nY4G4tEwAyPubK3yD3t3rm1n1st1cM4rk3tD4t4==";
                endpoint = "198.51.100.10:51820";
                allowedIPs = [ "10.250.0.1/32" ];
                persistentKeepalive = 10;
              };
            };
          };
        };

        database = {
          schema = {
            engine = "clickhouse";
            tables = {
              "order_book_ticks" = {
                columns = {
                  "timestamp" = { type = "timestamptz"; nullable = false; primaryKey = true; };
                  "symbol" = { type = "varchar"; nullable = false; primaryKey = true; };
                  "bid_price" = { type = "double"; nullable = false; };
                  "bid_size" = { type = "bigint"; nullable = false; };
                  "ask_price" = { type = "double"; nullable = false; };
                  "ask_size" = { type = "bigint"; nullable = false; };
                  "sequence_num" = { type = "bigint"; nullable = false; };
                };
              };
            };
          };
        };
      };
    })
  ];
}
