# Praxis MicroVM Virtualization Specification

Praxis provides a declarative hardware virtualization abstraction (`modules/microvm/`) targeting modern minimalist virtual machine monitors (VMMs), specifically AWS Firecracker and Cloud-Hypervisor.

```
+========================================================================================+
|                              MICROVM ISOLATION ARCHITECTURE                            |
+========================================================================================+
|                                                                                        |
|  +----------------------------------------------------------------------------------+  |
|  |                             HOST LINUX KERNEL (KVM)                              |  |
|  |                                                                                  |  |
|  |   +--------------------------------------------------------------------------+   |  |
|  |   |                        FIRECRACKER JAILER CHROOT                         |   |  |
|  |   |   - Unshared Namespaces: PID, NET, IPC, UTS, User, Mount                 |   |  |
|  |   |   - Seccomp Filter: SCMP_ACT_KILL on unauthorized syscalls               |   |  |
|  |   |   - Cgroup v2 Limits: memory.max, cpu.max, io.weight                     |   |  |
|  |   |                                                                          |   |  |
|  |   |   +------------------------------------------------------------------+   |   |  |
|  |   |   |                     MINIMALIST GUEST RUNTIME                     |   |   |  |
|  |   |   |                                                                  |   |   |  |
|  |   |   |   [ vCPU 0 ] [ vCPU 1 ]  <-- Hard-pinned to isolated host pCPUs  |   |   |  |
|  |   |   |   [ 1GB Hugepage Backing ] <-- Transparent hugepages (hugetlbfs) |   |   |  |
|  |   |   |                                                                  |   |   |  |
|  |   |   |   +-------------------+  +-------------------+  +------------+   |   |   |  |
|  |   |   |   |   virtio-block    |  |    virtio-net     |  |virtio-vsock|   |   |   |  |
|  |   |   |   | (Direct I/O O_DIR)|  | (Multi-queue XDP) |  | (Host RPC) |   |   |   |  |
|  |   |   |   +-------------------+  +-------------------+  +------------+   |   |   |  |
|  |   |   |             |                      |                   |         |   |   |  |
|  |   |   |             v                      v                   v         |   |   |  |
|  |   |   |   +-------------------+  +-------------------+  +------------+   |   |   |  |
|  |   |   |   |  LUKS2 Rootfs /   |  | TAP / Macvtap Net |  | AF_VSOCK   |   |   |   |  |
|  |   |   |   |  dm-verity Tree   |  | Host Interface    |  | Channel    |   |   |   |  |
|  |   |   |   +-------------------+  +-------------------+  +------------+   |   |   |  |
|  |   |   +------------------------------------------------------------------+   |   |  |
|  |   +--------------------------------------------------------------------------+   |  |
|  +----------------------------------------------------------------------------------+  |
+========================================================================================+
```

---

## 1. Minimalist Kernel Cmdline Generation

Praxis constructs hardened, deterministic kernel command lines designed for sub-5 millisecond boot times and minimal attack surfaces:

```
console=ttyS0 reboot=k panic=1 pci=off i8042.noaux quiet loglevel=3 \
mitigations=auto,nosmt selinux=0 init=/init rw root=/dev/vda
```

Key kernel parameters enforced by default:
- `pci=off`: Disables ACPI and PCI bus probing, eliminating enumeration latency in minimalist microVMs that use MMIO for virtio devices.
- `i8042.noaux`: Disables legacy PS/2 auxiliary mouse port probing.
- `panic=1`: Ensures immediate guest reboot on kernel panic, triggering supervisor recovery workflows.
- `reboot=k`: Forces immediate kernel restart via ACPI reset or triple fault without BIOS handoff.
- `mitigations=auto,nosmt`: Configures hardware vulnerability mitigations while disabling simultaneous multithreading (SMT) on sensitive guest workloads to prevent cross-hyperthread side-channel attacks (Spectre/L1TF).

---

## 2. Compute and Memory Partitioning

### 2.1 Deterministic vCPU Pinning
To guarantee predictable execution latency and eliminate scheduler jitter, Praxis enforces 1-to-1 pinning of guest virtual CPUs to dedicated physical CPU cores (`isolcpus`):

```nix
microvm.vcpu = {
  count = 4;
  affinity = [ 2 3 4 5 ]; # Pinned to physical host cores 2-5
  smt = false;            # Disable hyperthreading allocation
};
```

When evaluated, the engine produces cgroup configuration directives:
```
cpuset.cpus = "2,3,4,5"
cpuset.mems = "0"
```

### 2.2 Hugepage Backing
Praxis supports backing guest physical memory using either 2MB or 1GB hugepages via Linux `hugetlbfs`:
- **TLB Miss Elimination**: Reduces page table depth from 4 levels to 2 levels, dramatically cutting memory access latency in high-throughput workloads.
- **Zero Swapping**: Hugepage memory is automatically mlocked in host RAM, preventing host kernel swap daemons from evicting guest pages.

---

## 3. VirtIO Device Stack

| Device Type | Driver | Configuration Options | Performance Characteristics |
| :--- | :--- | :--- | :--- |
| **Storage** | `virtio-blk` | `path`, `read_only`, `direct_io` | Bypasses host page cache using `O_DIRECT`, preventing buffer duplication |
| **Network** | `virtio-net` | `tap_name`, `mac`, `queues` | Multi-queue support with ring buffers aligned to vCPU count |
| **Inter-Process** | `virtio-vsock` | `guest_cid`, `listen_port` | High-speed zero-copy host-guest communication over `AF_VSOCK` |
| **Entropy** | `virtio-rng` | Rate-limited entropy pool | Seeds guest kernel `/dev/urandom` from host hardware CSPRNG |

---

## 4. Jailer Confinement and Seccomp Sandboxing

The Praxis microVM supervisor executes each VMM instance under an unprivileged jailer wrapper providing defense-in-depth isolation:

```
/usr/bin/jailer \
  --id vm-prod-worker-01 \
  --exec-file /usr/bin/firecracker \
  --uid 10001 \
  --gid 10001 \
  --chroot-base-dir /srv/jailer \
  --netns /var/run/netns/vm-prod-worker-01 \
  --daemon
```

### 4.1 Namespace Separation
- **PID Namespace**: The VMM cannot observe or signal any host processes outside its jail.
- **Network Namespace**: The VMM is isolated in a private network namespace, connected to the host bridge solely via a dedicated TAP device.
- **Mount Namespace**: The filesystem is confined to a minimal, read-only chroot jail containing only the guest kernel and rootfs disk images.

### 4.2 System Call Filtering (Seccomp BPF)
Praxis compiles a strict seccomp BPF filter using `SCMP_ACT_KILL` as the default action. The VMM is permitted only the minimal system calls required for KVM ioctls, event polling, and asynchronous file I/O:
- Permitted: `read`, `write`, `epoll_wait`, `ioctl` (`KVM_RUN`, `KVM_SET_USER_MEMORY_REGION`), `futex`, `sigreturn`.
- Denied and killed: `execve`, `fork`, `clone` (without CLONE_VM), `ptrace`, `socket` (outside pre-created network namespace descriptors).

---

## 5. Storage Integrity and Encryption

Praxis generates cryptographic storage definitions for microVM root disks:
1. **LUKS2 Sealed Rootfs**: Full disk encryption utilizing AES-XTS-256 with keys sealed via host TPM 2.0 or hardware security modules (HSMs).
2. **dm-verity Cryptographic Verification**: Immutable root filesystems are paired with a SHA-256 hash tree. The guest kernel verifies block integrity on every read, immediately halting I/O if tampering is detected.
