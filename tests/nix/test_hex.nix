# Praxis Pure Nix Test Suite: Hexadecimal Encoding & Decoding

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  hex = lib.hex;

in
runner.runSuite "hex" [
  (runner.testCase "byte_to_hex" (_:
    hex.byteToHex 0 == "00" &&
    hex.byteToHex 15 == "0f" &&
    hex.byteToHex 255 == "ff" &&
    hex.byteToHex 170 == "aa"
  ))

  (runner.testCase "bytes_to_hex_and_back" (_:
    let
      original = [ 0 10 255 128 64 32 ];
      hexStr = hex.bytesToHex original;
      recovered = hex.hexToBytes hexStr;
    in
    hexStr == "000aff804020" &&
    recovered == original
  ))

  (runner.testCase "int32_to_hex" (_:
    hex.int32ToHex 0 == "00000000" &&
    hex.int32ToHex 305419896 == "12345678" &&
    hex.int32ToHex 4294967295 == "ffffffff"
  ))
]
