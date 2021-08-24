# Hermetic development shell for Praxis
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "praxis-dev-shell";

  packages = with pkgs; [
    cargo
    rustc
    rustfmt
    clippy
    python3
    clang
    pkg-config
    git
  ];

  shellHook = ''
    export RUST_BACKTRACE=1
    echo "Welcome to Praxis development shell"
    echo "Run './test.sh' to execute the full verification suite."
  '';
}
