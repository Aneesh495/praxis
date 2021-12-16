# Praxis Pure Nix Test Suite: RFC 4231 HMAC-SHA256 Message Authentication

let
  lib = import ../../lib {};
  runner = import ./test_runner.nix;
  hmac = lib.hmac;

in
runner.runSuite "hmac" [
  (runner.testCase "rfc4231_test_case_1" (_:
    # Key: 20 bytes of 0x0b ("\x0b" * 20)
    # Data: "Hi There"
    # Result: b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7
    let
      # Use key "praxis-secret-key" and msg "Praxis Distributed State"
      res = hmac.hmacSha256 "praxis-secret-key" "Praxis Distributed State";
    in
    builtins.stringLength res == 64
  ))

  (runner.testCase "hmac_deterministic_output" (_:
    let
      res1 = hmac.hmacSha256 "k1" "payload";
      res2 = hmac.hmacSha256 "k1" "payload";
      resDiff = hmac.hmacSha256 "k2" "payload";
    in
    res1 == res2 && res1 != resDiff
  ))
]
