# Praxis Declarative Infrastructure Hypervisor
# Network Module: Edge Ingress, Reverse Proxy, and Traffic Management
#
# Generates Envoy and Caddy reverse proxy routing tables, virtual hosts,
# HTTP/3 QUIC transport parameters, token-bucket rate limiters, and backend health checks.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.network.ingress = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to provision edge ingress reverse proxy gateways.";
    };

    proxyEngine = lib.mkOption {
      type = types.enum [ "envoy" "caddy" ];
      default = "envoy";
      description = "Reverse proxy engine backend.";
    };

    httpPort = lib.mkOption {
      type = types.port;
      default = 80;
      description = "Plaintext HTTP port (automatically redirects to HTTPS).";
    };

    httpsPort = lib.mkOption {
      type = types.port;
      default = 443;
      description = "TLS encrypted HTTPS listening port.";
    };

    http3 = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Enable HTTP/3 (QUIC over UDP) on HTTPS port.";
    };

    virtualHosts = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          domains = lib.mkOption {
            type = types.listOf types.str;
            description = "DNS domains matched by this virtual host.";
          };

          routes = lib.mkOption {
            type = types.listOf (types.submodule {
              options = {
                pathPrefix = lib.mkOption { type = types.str; default = "/"; description = "URL path prefix."; };
                backendService = lib.mkOption { type = types.str; description = "Upstream cluster service name."; };
                backendPort = lib.mkOption { type = types.port; description = "Upstream port."; };
                rateLimitRPS = lib.mkOption { type = types.nullOr types.int; default = null; description = "Requests per second token bucket limit."; };
                timeoutSec = lib.mkOption { type = types.int; default = 15; description = "Upstream request timeout in seconds."; };
              };
            });
            default = [];
            description = "URL route routing rules.";
          };
        };
      });
      default = {};
      description = "Virtual host configurations mapped by hostname.";
    };
  };
}
