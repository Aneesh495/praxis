# Praxis Declarative Infrastructure Hypervisor
# Cluster Module: Service Supervision and Dependency DAG Compiler
#
# Declares micro-services, background daemons, health-check probes,
# and compiles dependency DAGs into systemd unit hierarchies with cycle detection.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.cluster.services = lib.mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        description = lib.mkOption { type = types.str; default = ""; description = "Human readable service description."; };
        command = lib.mkOption { type = types.str; description = "Executable command line to start service."; };
        user = lib.mkOption { type = types.str; default = "praxis"; description = "Execution user account."; };
        dependsOn = lib.mkOption { type = types.listOf types.str; default = []; description = "Prerequisite service dependencies."; };
        restart = lib.mkOption { type = types.enum [ "always" "on-failure" "no" ]; default = "always"; description = "Restart policy."; };
        restartSec = lib.mkOption { type = types.int; default = 5; description = "Seconds to wait before restarting."; };
        sandbox = lib.mkOption { type = types.bool; default = true; description = "Apply zero-trust systemd security hardening."; };
        ports = lib.mkOption { type = types.listOf types.port; default = []; description = "Listening network ports."; };
        env = lib.mkOption { type = types.attrsOf types.str; default = {}; description = "Environment variables."; };
      };
    });
    default = {};
    description = "Declarative service specifications running under supervisor.";
  };
}
