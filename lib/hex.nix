# Praxis Pure Nix Standard Library
# Hexadecimal Encoding and Decoding Engine
#
# Provides bijective conversions between ASCII strings, byte arrays (integers 0..255),
# and lowercase hexadecimal representations in pure Nix.

rec {
  # Nibble to hex character lookup table
  hexDigits = [
    "0" "1" "2" "3" "4" "5" "6" "7"
    "8" "9" "a" "b" "c" "d" "e" "f"
  ];

  # Hex character to integer value mapping
  hexCharToVal = {
    "0" = 0;  "1" = 1;  "2" = 2;  "3" = 3;  "4" = 4;
    "5" = 5;  "6" = 6;  "7" = 7;  "8" = 8;  "9" = 9;
    "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
    "A" = 10; "B" = 11; "C" = 12; "D" = 13; "E" = 14; "F" = 15;
  };

  # Convert a byte (0..255) to a two-character lowercase hexadecimal string
  byteToHex = b:
    let
      hi = b / 16;
      lo = b - (hi * 16);
    in
    (builtins.elemAt hexDigits hi) + (builtins.elemAt hexDigits lo);

  # Convert a list of byte integers (0..255) to a hexadecimal string
  bytesToHex = bytes:
    builtins.concatStringsSep "" (builtins.map byteToHex bytes);

  # Convert a 32-bit integer into an 8-character hexadecimal string
  int32ToHex = val:
    let
      mod32 = 4294967296;
      v = val - (val / mod32) * mod32;
      b3 = v / 16777216;
      r3 = v - (b3 * 16777216);
      b2 = r3 / 65536;
      r2 = r3 - (b2 * 65536);
      b1 = r2 / 256;
      b0 = r2 - (b1 * 256);
    in
    byteToHex b3 + byteToHex b2 + byteToHex b1 + byteToHex b0;

  # Convert a hexadecimal string to a list of byte integers (0..255)
  hexToBytes = hexStr:
    let
      len = builtins.stringLength hexStr;
      # If length is odd, prepend a zero
      padded = if (len - (len / 2) * 2) != 0 then "0" + hexStr else hexStr;
      padLen = builtins.stringLength padded;
      numBytes = padLen / 2;

      go = idx:
        if idx >= numBytes then []
        else
          let
            cHi = builtins.substring (idx * 2) 1 padded;
            cLo = builtins.substring (idx * 2 + 1) 1 padded;
            vHi = if builtins.hasAttr cHi hexCharToVal then hexCharToVal.${cHi} else 0;
            vLo = if builtins.hasAttr cLo hexCharToVal then hexCharToVal.${cLo} else 0;
            byteVal = vHi * 16 + vLo;
          in
          [ byteVal ] ++ (go (idx + 1));
    in
    go 0;
}
