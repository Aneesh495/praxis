# Praxis Declarative Infrastructure Hypervisor
# OCI Module: OverlayFS Whiteout Markers and Opaque Directories
#
# Generates and handles OverlayFS whiteout file entries (.wh.<basename>)
# and opaque directory markers to represent file deletions and directory replacements
# across deterministic layer stacks in pure Nix.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.oci.whiteout = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to synthesize and parse OverlayFS whiteout markers.";
    };

    whiteoutPrefix = lib.mkOption {
      type = types.str;
      default = ".wh.";
      description = "Standard OCI layer whiteout file prefix.";
    };

    opaqueMarker = lib.mkOption {
      type = types.str;
      default = ".wh..wh..opq";
      description = "Standard OCI layer opaque directory marker filename.";
    };
  };
}
