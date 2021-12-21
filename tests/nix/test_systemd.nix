# Praxis Pure Nix Test Suite: Systemd Unit File Generator

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  systemd = lib.systemd;

in
runner.runSuite "systemd" [
  (runner.testCase "systemd_hardened_unit" (_:
    let
      unitDef = {
        Unit = {
          Description = "Praxis Node Daemon";
          After = [ "network.target" ];
        };
        Service = {
          ExecStart = "/usr/bin/praxis-node --daemon";
          User = "praxis";
          sandbox = true; # Injects ProtectSystem=strict, PrivateTmp=true
        };
        Install = {
          WantedBy = [ "multi-user.target" ];
        };
      };
      res = systemd.renderUnit unitDef;
    in
    builtins.match ".*\\[Unit\\].*" res != null &&
    builtins.match ".*\\[Service\\].*" res != null &&
    builtins.match ".*ProtectSystem=strict.*" res != null &&
    builtins.match ".*PrivateTmp=true.*" res != null &&
    builtins.match ".*\\[Install\\].*" res != null
  ))
]
