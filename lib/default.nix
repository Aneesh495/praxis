# Praxis Pure Nix Standard Library Root
#
# Ties all functional primitives, data structures, graph theory algorithms,
# cryptographic hashing cores, serializations, and module evaluation systems
# into a coherent self-referential library fixed point.

{ lib ? null }:

let
  functional = import ./functional.nix;

  # Self-tying library fixed point
  praxisLib = functional.fix (self: {
    inherit functional;

    types = import ./types.nix { lib = self; };
    modules = import ./modules.nix { lib = self; };
    assertions = import ./assertions.nix;

    # Persistent Data Structures
    rbtree = import ./rbtree.nix;
    trie = import ./trie.nix;
    heap = import ./heap.nix;
    disjointSet = import ./disjoint_set.nix;
    bitset = import ./bitset.nix;

    # Graph Theory & Topology
    tarjan = import ./tarjan.nix;
    toposort = import ./toposort.nix;
    shortestPath = import ./shortest_path.nix;
    dominator = import ./dominator.nix;
    transitive = import ./transitive.nix;

    # Cryptography & Encoding
    hex = import ./hex.nix;
    base64 = import ./base64.nix;
    sha256 = import ./sha256.nix;
    hmac = import ./hmac.nix;
    uuid = import ./uuid.nix;
    semver = import ./semver.nix;

    # Serialization & Formats
    json = import ./json.nix;
    yaml = import ./yaml.nix;
    toml = import ./toml.nix;
    systemd = import ./systemd.nix;
    shellGen = import ./shell_gen.nix;
    cgroup = import ./cgroup.nix;

    # Convenience shortcuts
    inherit (self.modules) mkOption mkEnableOption mkOverride mkForce mkDefault evalModules isOption;
    inherit (self.assertions) mkAssertion verifyAll;
  });
in
praxisLib
