# Praxis Pure Nix Test Suite: RFC 4648 Base64 Encoding & Decoding

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  base64 = lib.base64;

in
runner.runSuite "base64" [
  (runner.testCase "rfc4648_test_vectors" (_:
    # "Man" (ASCII 77, 97, 110) -> "TWFu"
    # "Ma"  (ASCII 77, 97)      -> "TWE="
    # "M"   (ASCII 77)          -> "TQ=="
    let
      res3 = base64.encodeBytes [ 77 97 110 ];
      res2 = base64.encodeBytes [ 77 97 ];
      res1 = base64.encodeBytes [ 77 ];
    in
    res3 == "TWFu" &&
    res2 == "TWE=" &&
    res1 == "TQ=="
  ))

  (runner.testCase "base64_decode_vectors" (_:
    let
      dec3 = base64.decodeToBytes "TWFu";
      dec2 = base64.decodeToBytes "TWE=";
      dec1 = base64.decodeToBytes "TQ==";
    in
    dec3 == [ 77 97 110 ] &&
    dec2 == [ 77 97 ] &&
    dec1 == [ 77 ]
  ))

  (runner.testCase "roundtrip_encode_decode" (_:
    let
      original = [ 0 15 240 255 128 64 32 16 8 4 2 1 ];
      encoded = base64.encodeBytes original;
      decoded = base64.decodeToBytes encoded;
    in
    decoded == original
  ))
]
