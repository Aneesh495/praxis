# Praxis Declarative Infrastructure Hypervisor
# OCI Module: Content-Addressable Layer Chunking & Closure Deduplication
#
# Partitions package dependency closures into optimal layer hierarchies
# (base runtime, shared libraries, language runtime, application assets)
# to maximize container registry layer caching and minimize network transfer.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.oci.layers = {
    strategy = lib.mkOption {
      type = types.enum [ "single-layer" "tiered-closure" "per-package" ];
      default = "tiered-closure";
      description = "Strategy for grouping package closures into OCI tarball layers.";
    };

    maxLayers = lib.mkOption {
      type = types.int;
      default = 16;
      description = "Maximum number of tarball layers allowed in synthesized image.";
    };

    compression = lib.mkOption {
      type = types.enum [ "gzip" "zstd" "none" ];
      default = "gzip";
      description = "Compression format for OCI tarball layer blobs.";
    };

    reproducibleTimestamps = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Clamp all tar member mtimes to Unix epoch 1 (1970-01-01 00:00:01) for bit-for-bit reproducibility.";
    };
  };
}
