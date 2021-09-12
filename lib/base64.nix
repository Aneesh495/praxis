# Praxis Pure Nix Standard Library
# RFC 4648 Base64 Encoding and Decoding Engine
#
# Implements standard Base64 encoding and decoding in pure Nix.
# Converts between raw byte arrays, ASCII strings, and RFC 4648 Base64 strings.

rec {
  # Base64 standard alphabet
  base64Chars = [
    "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M"
    "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z"
    "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m"
    "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"
    "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "+" "/"
  ];

  # Inverse mapping from character to 6-bit index (0..63)
  charToVal = {
    "A"=0;  "B"=1;  "C"=2;  "D"=3;  "E"=4;  "F"=5;  "G"=6;  "H"=7;
    "I"=8;  "J"=9;  "K"=10; "L"=11; "M"=12; "N"=13; "O"=14; "P"=15;
    "Q"=16; "R"=17; "S"=18; "T"=19; "U"=20; "V"=21; "W"=22; "X"=23;
    "Y"=24; "Z"=25; "a"=26; "b"=27; "c"=28; "d"=29; "e"=30; "f"=31;
    "g"=32; "h"=33; "i"=34; "j"=35; "k"=36; "l"=37; "m"=38; "n"=39;
    "o"=40; "p"=41; "q"=42; "r"=43; "s"=44; "t"=45; "u"=46; "v"=47;
    "w"=48; "x"=49; "y"=50; "z"=51; "0"=52; "1"=53; "2"=54; "3"=55;
    "4"=56; "5"=57; "6"=58; "7"=59; "8"=60; "9"=61; "+"=62; "/"=63;
  };

  # Encodes a list of byte integers (0..255) into an RFC 4648 Base64 string
  encodeBytes = bytes:
    let
      len = builtins.length bytes;
      go = idx:
        if idx >= len then ""
        else if (len - idx) >= 3 then
          let
            b0 = builtins.elemAt bytes idx;
            b1 = builtins.elemAt bytes (idx + 1);
            b2 = builtins.elemAt bytes (idx + 2);

            c0 = b0 / 4;
            c1 = ((b0 - (c0 * 4)) * 16) + (b1 / 16);
            c2 = ((b1 - ((b1 / 16) * 16)) * 4) + (b2 / 64);
            c3 = b2 - ((b2 / 64) * 64);

            chars = (builtins.elemAt base64Chars c0) +
                    (builtins.elemAt base64Chars c1) +
                    (builtins.elemAt base64Chars c2) +
                    (builtins.elemAt base64Chars c3);
          in
          chars + (go (idx + 3))

        else if (len - idx) == 2 then
          let
            b0 = builtins.elemAt bytes idx;
            b1 = builtins.elemAt bytes (idx + 1);

            c0 = b0 / 4;
            c1 = ((b0 - (c0 * 4)) * 16) + (b1 / 16);
            c2 = (b1 - ((b1 / 16) * 16)) * 4;

            chars = (builtins.elemAt base64Chars c0) +
                    (builtins.elemAt base64Chars c1) +
                    (builtins.elemAt base64Chars c2) +
                    "=";
          in
          chars

        else # (len - idx) == 1
          let
            b0 = builtins.elemAt bytes idx;

            c0 = b0 / 4;
            c1 = (b0 - (c0 * 4)) * 16;

            chars = (builtins.elemAt base64Chars c0) +
                    (builtins.elemAt base64Chars c1) +
                    "==";
          in
          chars;
    in
    go 0;

  # Decodes an RFC 4648 Base64 string into a list of byte integers (0..255)
  decodeToBytes = b64Str:
    let
      # Strip whitespaces and trailing padding
      len = builtins.stringLength b64Str;
      cleanStr =
        let
          chars = builtins.genList (i: builtins.substring i 1 b64Str) len;
          filtered = builtins.filter (c: c != "\n" && c != "\r" && c != " " && c != "\t") chars;
        in
        builtins.concatStringsSep "" filtered;

      cleanLen = builtins.stringLength cleanStr;

      go = idx:
        if idx >= cleanLen then []
        else
          let
            ch0 = builtins.substring idx 1 cleanStr;
            ch1 = builtins.substring (idx + 1) 1 cleanStr;
            ch2 = builtins.substring (idx + 2) 1 cleanStr;
            ch3 = builtins.substring (idx + 3) 1 cleanStr;

            v0 = if builtins.hasAttr ch0 charToVal then charToVal.${ch0} else 0;
            v1 = if builtins.hasAttr ch1 charToVal then charToVal.${ch1} else 0;
            v2 = if builtins.hasAttr ch2 charToVal then charToVal.${ch2} else 0;
            v3 = if builtins.hasAttr ch3 charToVal then charToVal.${ch3} else 0;

            b0 = (v0 * 4) + (v1 / 16);
            b1 = ((v1 - ((v1 / 16) * 16)) * 16) + (v2 / 4);
            b2 = ((v2 - ((v2 / 4) * 4)) * 64) + v3;
          in
          if ch2 == "=" then
            [ b0 ]
          else if ch3 == "=" then
            [ b0 b1 ]
          else
            [ b0 b1 b2 ] ++ (go (idx + 4));
    in
    if cleanLen == 0 then [] else go 0;
}
