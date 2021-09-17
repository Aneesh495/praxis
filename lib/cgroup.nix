# Praxis Pure Nix Standard Library
# Cgroup v2 Unified Resource Controller Generator
#
# Generates Linux cgroup v2 controller configurations for MicroVMs,
# container runtimes, and systemd slices in pure Nix.

rec {
  # Default cgroup v2 resource configuration
  defaultLimits = {
    cpuWeight = 100;       # 1..10000 (default 100)
    cpuMaxQuota = "max";   # "max" or integer microseconds
    cpuMaxPeriod = 100000; # 100,000 microseconds (100ms)
    memoryHighBytes = null;# Soft limit
    memoryMaxBytes = null; # Hard limit (OOM killer threshold)
    memorySwapMax = 0;     # Swap limit (0 = disable swap)
    ioWeight = 100;        # 1..10000
    pidsMax = 4096;        # Max tasks in cgroup
  };

  # Synthesizes systemd unit resource directives from cgroup limits
  toSystemdResourceLimits = limits:
    let
      l = defaultLimits // limits;
      entries = [
        "CPUWeight=${toString l.cpuWeight}"
        "CPUQuota=${if l.cpuMaxQuota == "max" then "" else "${toString ((l.cpuMaxQuota * 100) / l.cpuMaxPeriod)}%"}"
        "TasksMax=${toString l.pidsMax}"
      ] ++ (if l.memoryHighBytes != null then [ "MemoryHigh=${toString l.memoryHighBytes}" ] else [])
        ++ (if l.memoryMaxBytes != null then [ "MemoryMax=${toString l.memoryMaxBytes}" ] else [])
        ++ [ "MemorySwapMax=${toString l.memorySwapMax}" "IOWeight=${toString l.ioWeight}" ];
    in
    builtins.filter (e: !builtins.match ".*=$" e) entries;

  # Synthesizes raw cgroup v2 file writes for a cgroup path:
  # e.g. /sys/fs/cgroup/praxis/<name>
  toCgroupV2Files = limits:
    let
      l = defaultLimits // limits;
    in
    {
      "cpu.weight" = toString l.cpuWeight;
      "cpu.max" = "${toString l.cpuMaxQuota} ${toString l.cpuMaxPeriod}";
      "memory.high" = if l.memoryHighBytes != null then toString l.memoryHighBytes else "max";
      "memory.max" = if l.memoryMaxBytes != null then toString l.memoryMaxBytes else "max";
      "memory.swap.max" = toString l.memorySwapMax;
      "io.weight" = toString l.ioWeight;
      "pids.max" = toString l.pidsMax;
    };
}
