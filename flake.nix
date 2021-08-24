{
  description = "Praxis: Declarative cloud operating fabric and zero-trust infrastructure hypervisor in pure Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Pure Nix library exported without system dependency
      praxisLib = import ./lib { inherit (nixpkgs) lib; };
      praxisModules = import ./modules { lib = praxisLib; };
      praxisTopologies = import ./topologies { lib = praxisLib; modules = praxisModules; };
    in
    {
      # Export pure Nix subsystems
      lib = praxisLib;
      modules = praxisModules;
      topologies = praxisTopologies;

      # Pure Nix evaluation entrypoints
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
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          default = pkgs.rustPlatform.buildRustPackage {
            pname = "praxis";
            version = "0.1.0";
            src = ./engine;
            cargoLock = {
              lockFile = ./engine/Cargo.lock;
            };
          };

          praxis-cli = self.packages.${system}.default;
        };

        apps = {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/praxis";
          };
        };

        checks = {
          lib-tests = pkgs.runCommand "praxis-lib-tests" {
            nativeBuildInputs = [ pkgs.python3 ];
          } ''
            python3 ${./tests/test_harness.py} --suite nix
            touch $out
          '';

          engine-tests = pkgs.runCommand "praxis-engine-tests" {
            nativeBuildInputs = [ pkgs.cargo pkgs.rustc ];
          } ''
            cd ${./engine}
            cargo test --release
            touch $out
          '';
        };

        devShells.default = pkgs.mkShell {
          name = "praxis-dev-shell";
          packages = with pkgs; [
            cargo
            rustc
            rustfmt
            clippy
            python3
            clang
            pkg-config
          ];

          shellHook = ''
            echo "Praxis development environment loaded."
            echo "Available commands: cargo test, python3 tests/test_harness.py, ./test.sh"
          '';
        };
      });
}
