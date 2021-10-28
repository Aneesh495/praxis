# Praxis Production Blueprint
# Topology: Global Sovereign Cloud Fabric with Distributed Raft & Mesh
#
# Configures a 3-region sovereign cloud fabric (us-east, eu-central, ap-southeast)
# with a distributed Raft consensus core, full-mesh WireGuard overlay,
# split-horizon internal DNS, Envoy HTTP/3 edge ingress, and mTLS PKI.

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
        cluster = {
          topology = {
            clusterName = "praxis-sovereign-mesh";
            regions = {
              "us-east" = { location = "North Virginia"; zones = [ "a" "b" ]; };
              "eu-central" = { location = "Frankfurt"; zones = [ "a" "b" ]; };
              "ap-southeast" = { location = "Singapore"; zones = [ "a" "b" ]; };
            };
            nodes = {
              "us-control-01" = { region = "us-east"; zone = "a"; overlayIP = "10.200.1.1"; roles = [ "control-plane" "gateway" ]; };
              "us-worker-01" = { region = "us-east"; zone = "b"; overlayIP = "10.200.1.2"; roles = [ "compute" ]; };
              "eu-control-01" = { region = "eu-central"; zone = "a"; overlayIP = "10.200.2.1"; roles = [ "control-plane" ]; };
              "eu-worker-01" = { region = "eu-central"; zone = "b"; overlayIP = "10.200.2.2"; roles = [ "compute" ]; };
              "ap-control-01" = { region = "ap-southeast"; zone = "a"; overlayIP = "10.200.3.1"; roles = [ "control-plane" ]; };
            };
          };

          raft = {
            enable = true;
            groupId = "sovereign-core";
            heartbeatIntervalMs = 150;
            electionTimeoutMinMs = 1500;
            electionTimeoutMaxMs = 3000;
            peers = {
              "us-control-01" = { nodeId = 1; address = "10.200.1.1:7000"; isVoter = true; };
              "eu-control-01" = { nodeId = 2; address = "10.200.2.1:7000"; isVoter = true; };
              "ap-control-01" = { nodeId = 3; address = "10.200.3.1:7000"; isVoter = true; };
            };
          };
        };

        network = {
          wireguard = {
            enable = true;
            listenPort = 51820;
            overlayCidr = "10.200.0.0/16";
            peers = {
              "eu-control-01" = {
                publicKey = "EUc0ntr0l1PubK3yD3t3rm1n1st1cW1r3gu4rd==";
                endpoint = "198.51.100.20:51820";
                allowedIPs = [ "10.200.2.0/24" ];
              };
              "ap-control-01" = {
                publicKey = "APc0ntr0l1PubK3yD3t3rm1n1st1cW1r3gu4rd==";
                endpoint = "198.51.100.30:51820";
                allowedIPs = [ "10.200.3.0/24" ];
              };
            };
          };

          dns = {
            enable = true;
            domain = "sovereign.internal";
            records = {
              "raft.sovereign.internal" = { type = "A"; value = "10.200.1.1"; };
              "auth.sovereign.internal" = { type = "A"; value = "10.200.1.2"; };
              "db.sovereign.internal" = { type = "A"; value = "10.200.2.1"; };
            };
          };

          ingress = {
            enable = true;
            proxyEngine = "envoy";
            http3 = true;
            virtualHosts = {
              "api.praxis.cloud" = {
                domains = [ "api.praxis.cloud" ];
                routes = [
                  { pathPrefix = "/v1/auth"; backendService = "auth-service"; backendPort = 8081; rateLimitRPS = 100; timeoutSec = 5; }
                  { pathPrefix = "/v1/query"; backendService = "query-service"; backendPort = 8082; rateLimitRPS = 500; timeoutSec = 10; }
                ];
              };
            };
          };
        };

        database = {
          schema = {
            engine = "postgresql";
            tables = {
              "accounts" = {
                columns = {
                  "id" = { type = "uuid"; nullable = false; primaryKey = true; };
                  "username" = { type = "varchar"; nullable = false; };
                  "email" = { type = "varchar"; nullable = false; };
                  "created_at" = { type = "timestamptz"; nullable = false; default = "CURRENT_TIMESTAMP"; };
                  "balance" = { type = "numeric"; nullable = false; default = "0"; };
                };
                indexes = {
                  "idx_accounts_email" = { columns = [ "email" ]; unique = true; method = "btree"; };
                };
              };
            };
          };
        };
      };
    })
  ];
}
