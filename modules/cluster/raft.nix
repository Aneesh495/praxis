# Praxis Declarative Infrastructure Hypervisor
# Cluster Module: Raft Consensus State Machine & Quorum Calculations
#
# Declares distributed Raft consensus groups, peer voter/non-voter matrices,
# heartbeat intervals, randomized election timeout windows, and snapshot thresholds.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.cluster.raft = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to provision Raft distributed consensus for cluster metadata.";
    };

    groupId = lib.mkOption {
      type = types.str;
      default = "praxis-consensus";
      description = "Consensus group identifier.";
    };

    heartbeatIntervalMs = lib.mkOption {
      type = types.int;
      default = 100;
      description = "Leader heartbeat ping interval in milliseconds.";
    };

    electionTimeoutMinMs = lib.mkOption {
      type = types.int;
      default = 1000;
      description = "Minimum randomized election timeout in milliseconds.";
    };

    electionTimeoutMaxMs = lib.mkOption {
      type = types.int;
      default = 2000;
      description = "Maximum randomized election timeout in milliseconds.";
    };

    snapshotIntervalEntries = lib.mkOption {
      type = types.int;
      default = 10000;
      description = "Number of committed WAL log entries before compaction snapshot.";
    };

    peers = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          nodeId = lib.mkOption { type = types.int; description = "Numeric 64-bit Raft member ID."; };
          address = lib.mkOption { type = types.str; description = "Raft peer RPC address:port."; };
          isVoter = lib.mkOption { type = types.bool; default = true; description = "Whether peer participates in quorum voting."; };
        };
      });
      default = {};
      description = "Consensus peer cluster membership.";
    };
  };
}
