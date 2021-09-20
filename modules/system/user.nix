# Praxis Declarative Infrastructure Hypervisor
# System Module: Identity, Users, and Groups
#
# Declares deterministic system accounts, system groups, fixed UIDs/GIDs,
# and cryptographic SSH authorized key distributions.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.system.users = lib.mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        uid = lib.mkOption {
          type = types.int;
          description = "Fixed deterministic numeric user identifier (UID).";
        };

        group = lib.mkOption {
          type = types.str;
          default = "users";
          description = "Primary group name.";
        };

        extraGroups = lib.mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Supplementary group memberships.";
        };

        shell = lib.mkOption {
          type = types.str;
          default = "/bin/bash";
          description = "Login shell path.";
        };

        home = lib.mkOption {
          type = types.str;
          default = "/var/empty";
          description = "Home directory path.";
        };

        isSystemUser = lib.mkOption {
          type = types.bool;
          default = true;
          description = "Whether account represents a daemon system service.";
        };

        sshKeys = lib.mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Public SSH authorized keys (e.g. ssh-ed25519 ...).";
        };
      };
    });
    default = {
      praxis = {
        uid = 1000;
        group = "praxis";
        home = "/var/lib/praxis";
        isSystemUser = true;
        shell = "/sbin/nologin";
        sshKeys = [];
      };
    };
    description = "Declarative user accounts mapping.";
  };
}
