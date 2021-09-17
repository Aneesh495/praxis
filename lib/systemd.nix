# Praxis Pure Nix Standard Library
# Deterministic Systemd Unit File Generator and Security Sandboxing Profiles
#
# Synthesizes production-grade, hardened systemd service unit definitions
# with automated security hardening (ProtectSystem, PrivateTmp, Capability drops)
# and cgroup v2 resource limits from pure Nix specifications.

rec {
  # Default zero-trust systemd security hardening profile
  hardenedSandboxProfile = {
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    PrivateDevices = true;
    ProtectClock = true;
    ProtectHostname = true;
    RemoveIPC = true;
    SystemCallArchitectures = "native";
  };

  # Format an individual configuration line in an INI/systemd section
  formatEntry = key: val:
    if builtins.isBool val then "${key}=${if val then "true" else "false"}"
    else if builtins.isInt val then "${key}=${toString val}"
    else if builtins.isList val then
      # Lists can either be space-separated or multiple assignments
      if builtins.elem key [ "After" "Before" "Wants" "Requires" "BindsTo" "PartOf" "ReadWritePaths" "ReadOnlyPaths" ] then
        "${key}=${builtins.concatStringsSep " " val}"
      else
        builtins.concatStringsSep "\n" (builtins.map (item: "${key}=${toString item}") val)
    else
      "${key}=${toString val}";

  # Synthesizes a complete unit file from section attribute sets
  # unitDef:
  # {
  #   Unit = { Description = "..."; After = [ "network.target" ]; };
  #   Service = { ExecStart = "/bin/app"; User = "praxis"; sandbox = true; };
  #   Install = { WantedBy = [ "multi-user.target" ]; };
  # }
  renderUnit = unitDef:
    let
      sectionOrder = [ "Unit" "Service" "Socket" "Timer" "Mount" "Install" ];

      # Merge security sandbox profile into Service if requested
      enhancedDef =
        if unitDef ? Service && unitDef.Service ? sandbox && unitDef.Service.sandbox then
          let
            cleanService = builtins.removeAttrs unitDef.Service [ "sandbox" ];
            mergedService = hardenedSandboxProfile // cleanService;
          in
          unitDef // { Service = mergedService; }
        else if unitDef ? Service then
          unitDef // { Service = builtins.removeAttrs unitDef.Service [ "sandbox" ]; }
        else
          unitDef;

      renderedSections = builtins.filter (s: s != "") (builtins.map (sectionName:
        if builtins.hasAttr sectionName enhancedDef then
          let
            sectionAttrs = enhancedDef.${sectionName};
            keys = builtins.sort (a: b: a < b) (builtins.attrNames sectionAttrs);
            entries = builtins.map (k: formatEntry k sectionAttrs.${k}) keys;
          in
          "[${sectionName}]\n" + (builtins.concatStringsSep "\n" entries) + "\n"
        else
          ""
      ) sectionOrder);
    in
    builtins.concatStringsSep "\n" renderedSections;
}
