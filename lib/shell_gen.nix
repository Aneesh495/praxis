# Praxis Pure Nix Standard Library
# Deterministic POSIX / Bash Script Generator and Shell Escaping Engine
#
# Generates hermetic, strictly quoted shell scripts, early boot initramfs
# sequences, pivot_root handlers, and trap-based cleanup routines in pure Nix.

rec {
  # Escapes an arbitrary string for safe insertion into a POSIX shell command
  # Encloses string in single quotes, replacing any internal ' with '\''
  escapeShellArg = arg:
    let
      s = toString arg;
      escaped = builtins.replaceStrings [ "'" ] [ "'\\''" ] s;
    in
    "'${escaped}'";

  # Escapes a list of arguments into a single space-separated argument line
  escapeShellArgs = args:
    builtins.concatStringsSep " " (builtins.map escapeShellArg args);

  # Constructs a hardened bash script with set -euo pipefail and trap handlers
  makeScript = {
    name,
    header ? "#!/usr/bin/env bash\nset -euo pipefail",
    env ? {},
    cleanupTrap ? null,
    text,
  }:
    let
      envLines = builtins.map (k:
        "export ${k}=${escapeShellArg env.${k}}"
      ) (builtins.sort (a: b: a < b) (builtins.attrNames env));

      trapLine =
        if cleanupTrap != null then
          "trap ${escapeShellArg cleanupTrap} EXIT INT TERM"
        else
          "";

      scriptParts = [
        header
        ""
        "# Environment variable exports"
      ] ++ envLines ++ [
        ""
      ] ++ (if trapLine != "" then [ trapLine "" ] else []) ++ [
        "# Script Body"
        text
      ];
    in
    builtins.concatStringsSep "\n" scriptParts + "\n";

  # Generates an initramfs PID 1 early boot initialization script
  makeInitramfsScript = {
    rootDev,
    fstype ? "ext4",
    initPath ? "/sbin/init",
    extraMounts ? [],
  }:
    makeScript {
      name = "init";
      text = ''
        echo "[Praxis-Initramfs] Initializing early hardware devices..."
        mkdir -p /dev /proc /sys /mnt/root

        mount -t devtmpfs devtmpfs /dev
        mount -t proc proc /proc
        mount -t sysfs sysfs /sys

        echo "[Praxis-Initramfs] Mounting root filesystem from ${rootDev}..."
        mount -t ${fstype} ${rootDev} /mnt/root

        ${builtins.concatStringsSep "\n" (builtins.map (m: "mount ${m}") extraMounts)}

        echo "[Praxis-Initramfs] Executing pivot_root and switching to real system init..."
        exec switch_root /mnt/root ${initPath}
      '';
    };
}
