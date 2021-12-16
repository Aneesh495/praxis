# Praxis Pure Nix Test Suite: NIST SHA-256 Cryptographic Hash

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  sha256 = lib.sha256;

in
runner.runSuite "sha256" [
  (runner.testCase "nist_empty_string_vector" (_:
    let
      hash = sha256.hashString "";
    in
    hash == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  ))

  (runner.testCase "nist_abc_vector" (_:
    let
      hash = sha256.hashString "abc";
    in
    hash == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  ))

  (runner.testCase "nist_56_byte_chunk_boundary_vector" (_:
    let
      hash = sha256.hashString "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    in
    hash == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff21a7f7eced97a14496cb"
  ))
]
