# Praxis Pure Nix Standard Library
# NIST FIPS 180-4 SHA-256 Cryptographic Hash Engine
#
# Implements the complete NIST Secure Hash Algorithm 256 in pure Nix.
# Calculates bit-for-bit exact cryptographic hashes for SLSA provenance,
# package derivation closures, and content-addressable layer chunking.

let
  bitset = import ./bitset.nix;
  hex = import ./hex.nix;

  mod32 = 4294967296;
  add32 = a: b:
    let
      sum = a + b;
    in
    sum - (sum / mod32) * mod32;

  add32_3 = a: b: c: add32 (add32 a b) c;
  add32_4 = a: b: c: d: add32 (add32_3 a b c) d;
  add32_5 = a: b: c: d: e: add32 (add32_4 a b c d) e;

  # SHA-256 round constants (first 32 bits of fractional parts of cube roots of first 64 primes)
  K = [
    1116352408 1899447441 3049323471 3921009573  961987163 1508970993 2453635748 2870763221
    3624381080  310598401  607225278 1426881987 1925078388 2162078206 2614888103 3248222580
    3835390401 4022224774  264347078  604807628  770255983 1249150122 1555081692 1996064986
    2554220582 2821834349 2952996808 3210303692 3406560251 3903204099 4118501257   43829989
      83607582  252835263  471031174  550777172  720279685  978000473 1137026388 1407252729
    1572954304 1653526681 1876527918 2008064942 2417028168 2604594312 2768848148 3175210945
    3194098902 3451629820 3762283838 3967597026 4077308305  149199155  402322006  515349271
     650454796  772385474 1032831829 1247513511 1318184824 1470612678 1782040806 1935299249
  ];

  # Initial hash state H(0)
  initH = [
    1779033703 3144134277 1013904242 2773480762
    1359893119 2600822924  528734635 1541459225
  ];

  # Bitwise helper functions for SHA-256
  ch = x: y: z:
    bitset.xor32 (bitset.and32 x y) (bitset.and32 (bitset.not32 x) z);

  maj = x: y: z:
    bitset.xor32 (bitset.xor32 (bitset.and32 x y) (bitset.and32 x z)) (bitset.and32 y z);

  sigma0 = x:
    bitset.xor32 (bitset.xor32 (bitset.rotr32 x 2) (bitset.rotr32 x 13)) (bitset.rotr32 x 22);

  sigma1 = x:
    bitset.xor32 (bitset.xor32 (bitset.rotr32 x 6) (bitset.rotr32 x 11)) (bitset.rotr32 x 25);

  gamma0 = x:
    bitset.xor32 (bitset.xor32 (bitset.rotr32 x 7) (bitset.rotr32 x 18)) (bitset.shr32 x 3);

  gamma1 = x:
    bitset.xor32 (bitset.xor32 (bitset.rotr32 x 17) (bitset.rotr32 x 19)) (bitset.shr32 x 10);

in
rec {
  # Pads an arbitrary byte array according to SHA-256 standard.
  # 1. Append byte 0x80 (128).
  # 2. Append k zero bytes such that total length % 64 == 56.
  # 3. Append 8-byte big-endian bit length of original message.
  padMessage = bytes:
    let
      origLen = builtins.length bytes;
      bitLen = origLen * 8;

      # Compute padding zero bytes
      k =
        let
          rem = (origLen + 1) - (((origLen + 1) / 64) * 64);
        in
        if rem <= 56 then (56 - rem)
        else (120 - rem);

      zeroBytes = builtins.genList (_: 0) k;

      # 64-bit length split into 8 big-endian bytes
      b7 = bitLen - ((bitLen / 256) * 256);
      l6 = bitLen / 256;
      b6 = l6 - ((l6 / 256) * 256);
      l5 = l6 / 256;
      b5 = l5 - ((l5 / 256) * 256);
      l4 = l5 / 256;
      b4 = l4 - ((l4 / 256) * 256);
      l3 = l4 / 256;
      b3 = l3 - ((l3 / 256) * 256);
      l2 = l3 / 256;
      b2 = l2 - ((l2 / 256) * 256);
      l1 = l2 / 256;
      b1 = l1 - ((l1 / 256) * 256);
      b0 = l1 / 256;

      lengthBytes = [ b0 b1 b2 b3 b4 b5 b6 b7 ];
    in
    bytes ++ [ 128 ] ++ zeroBytes ++ lengthBytes;

  # Process a 64-byte chunk and update the 8-word hash state
  processChunk = chunk: state:
    let
      # Construct initial 16 words from 64 big-endian bytes
      wInitial = builtins.genList (t:
        let
          b0 = builtins.elemAt chunk (t * 4);
          b1 = builtins.elemAt chunk (t * 4 + 1);
          b2 = builtins.elemAt chunk (t * 4 + 2);
          b3 = builtins.elemAt chunk (t * 4 + 3);
        in
        (b0 * 16777216) + (b1 * 65536) + (b2 * 256) + b3
      ) 16;

      # Expand to 64 words message schedule
      expandSchedule = schedule: t:
        if t >= 64 then schedule
        else
          let
            w15 = builtins.elemAt schedule (t - 15);
            w2 = builtins.elemAt schedule (t - 2);
            w16 = builtins.elemAt schedule (t - 16);
            w7 = builtins.elemAt schedule (t - 7);
            s0 = gamma0 w15;
            s1 = gamma1 w2;
            wT = add32_4 s1 w7 s0 w16;
          in
          expandSchedule (schedule ++ [ wT ]) (t + 1);

      W = expandSchedule wInitial 16;

      # Run 64 compression rounds
      compressRounds = st: t:
        if t >= 64 then st
        else
          let
            a = builtins.elemAt st 0;
            b = builtins.elemAt st 1;
            c = builtins.elemAt st 2;
            d = builtins.elemAt st 3;
            e = builtins.elemAt st 4;
            f = builtins.elemAt st 5;
            g = builtins.elemAt st 6;
            h = builtins.elemAt st 7;

            s1Val = sigma1 e;
            chVal = ch e f g;
            kT = builtins.elemAt K t;
            wT = builtins.elemAt W t;
            temp1 = add32_5 h s1Val chVal kT wT;

            s0Val = sigma0 a;
            majVal = maj a b c;
            temp2 = add32 s0Val majVal;

            newA = add32 temp1 temp2;
            newE = add32 d temp1;
          in
          compressRounds [ newA a b c newE e f g ] (t + 1);

      roundResult = compressRounds state 0;

      # Add compressed chunk back into state
      newH = [
        (add32 (builtins.elemAt state 0) (builtins.elemAt roundResult 0))
        (add32 (builtins.elemAt state 1) (builtins.elemAt roundResult 1))
        (add32 (builtins.elemAt state 2) (builtins.elemAt roundResult 2))
        (add32 (builtins.elemAt state 3) (builtins.elemAt roundResult 3))
        (add32 (builtins.elemAt state 4) (builtins.elemAt roundResult 4))
        (add32 (builtins.elemAt state 5) (builtins.elemAt roundResult 5))
        (add32 (builtins.elemAt state 6) (builtins.elemAt roundResult 6))
        (add32 (builtins.elemAt state 7) (builtins.elemAt roundResult 7))
      ];
    in
    newH;

  # Computes the 256-bit hash of a byte array and formats it as 64-character lowercase hex string
  hashBytes = bytes:
    let
      padded = padMessage bytes;
      numChunks = (builtins.length padded) / 64;

      go = chunkIdx: state:
        if chunkIdx >= numChunks then state
        else
          let
            chunk = builtins.genList (i: builtins.elemAt padded (chunkIdx * 64 + i)) 64;
            nextState = processChunk chunk state;
          in
          go (chunkIdx + 1) nextState;

      finalState = go 0 initH;
    in
    builtins.concatStringsSep "" (builtins.map hex.int32ToHex finalState);

  # Hashes an ASCII string
  hashString = str:
    let
      len = builtins.stringLength str;
      # In pure Nix, builtins.hashString is available if supported by the host evaluator,
      # but this pure hashBytes fallback guarantees hermetic evaluation anywhere.
      bytes = hex.hexToBytes (builtins.concatStringsSep "" (builtins.genList (i:
        # Convert char to hex byte
        let
          char = builtins.substring i 1 str;
        in
        # Fallback to string byte translation
        hex.byteToHex (
          let
            # Mapping ASCII characters to integer byte codes
            asciiMap = {
              " "=32; "!"=33; "\""=34;"#"=35; "$"=36; "%"=37; "&"=38; "'"=39;
              "("=40; ")"=41; "*"=42; "+"=43; ","=44; "-"=45; "."=46; "/"=47;
              "0"=48; "1"=49; "2"=50; "3"=51; "4"=52; "5"=53; "6"=54; "7"=55;
              "8"=56; "9"=57; ":"=58; ";"=59; "<"=60; "="=61; ">"=62; "?"=63;
              "@"=64; "A"=65; "B"=66; "C"=67; "D"=68; "E"=69; "F"=70; "G"=71;
              "H"=72; "I"=73; "J"=74; "K"=75; "L"=76; "M"=77; "N"=78; "O"=79;
              "P"=80; "Q"=81; "R"=82; "S"=83; "T"=84; "U"=85; "V"=86; "W"=87;
              "X"=88; "Y"=89; "Z"=90; "["=91; "\\"=92;"]"=93; "^"=94; "_"=95;
              "`"=96; "a"=97; "b"=98; "c"=99; "d"=100;"e"=101;"f"=102;"g"=103;
              "h"=104;"i"=105;"j"=106;"k"=107;"l"=108;"m"=109;"n"=110;"o"=111;
              "p"=112;"q"=113;"r"=114;"s"=115;"t"=116;"u"=117;"v"=118;"w"=119;
              "x"=120;"y"=121;"z"=122;"{"=123;"|"=124;"}"=125;"~"=126;
              "\n"=10;"\r"=13;"\t"=9;
            };
          in
          if builtins.hasAttr char asciiMap then asciiMap.${char} else 63
        )
      ) len));
    in
    if builtins ? hashString then
      builtins.hashString "sha256" str
    else
      hashBytes bytes;
}
