# Classic nix-build and import entrypoint
{ pkgs ? import <nixpkgs> {} }:

let
  praxisLib = import ./lib { inherit (pkgs) lib; };
  praxisModules = import ./modules { lib = praxisLib; };
  praxisTopologies = import ./topologies { lib = praxisLib; modules = praxisModules; };
in
{
  lib = praxisLib;
  modules = praxisModules;
  topologies = praxisTopologies;

  evalSystem = configuration:
    praxisLib.evalModules {
      modules = [
        praxisModules.system
        praxisModules.microvm
        praxisModules.oci
        praxisModules.network
        praxisModules.cluster
        praxisModules.database
        praxisModules.provenance
        praxisModules.cloud
        configuration
      ];
    };

  praxis-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "praxis";
    version = "0.1.0";
    src = ./engine;
    cargoLock = {
      lockFile = ./engine/Cargo.lock;
    };
  };
}
