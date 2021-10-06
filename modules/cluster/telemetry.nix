# Praxis Declarative Infrastructure Hypervisor
# Cluster Module: Telemetry, Metrics Exporters, and Observability
#
# Declares OpenTelemetry collector endpoints, Prometheus scrape intervals,
# trace sample ratios, and Vector structured log collection pipelines.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.cluster.telemetry = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to provision cluster telemetry and observability.";
    };

    prometheus = {
      enable = lib.mkOption { type = types.bool; default = true; description = "Expose Prometheus /metrics endpoint."; };
      port = lib.mkOption { type = types.port; default = 9090; description = "Prometheus scrape port."; };
      scrapeIntervalSec = lib.mkOption { type = types.int; default = 15; description = "Metrics collection scrape interval."; };
    };

    openTelemetry = {
      enable = lib.mkOption { type = types.bool; default = true; description = "Enable OpenTelemetry gRPC trace export."; };
      endpoint = lib.mkOption { type = types.str; default = "otel-collector.praxis.internal:4317"; description = "OTLP gRPC collector address."; };
      samplingRatio = lib.mkOption { type = types.str; default = "1.0"; description = "Trace sampling probability (0.0 to 1.0)."; };
    };
  };
}
