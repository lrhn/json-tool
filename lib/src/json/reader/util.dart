// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Utility functions.

/// Used to validate the argument to [JsonReader.tryKey].
bool areSorted(List<String> candidates) {
  for (var i = 1; i < candidates.length; i++) {
    if (candidates[i - 1].compareTo(candidates[i]) > 0) return false;
  }
  return true;
}

bool isWhitespace(int char) =>
    char == $tab || char == $nl || char == $cr || char == $space;

/// ASCII character table with mapping from JSON-significant characters
/// to consecutive integers.
///
/// * `[`: 0
/// * `{`: 1
/// * `"`: 2
/// * `t`: 3
/// * `f`: 4
/// * `n`: 5
/// * `0`-`9`, `-`: 6
/// * `,`: 7
/// * `:`, 8
const jsonCharacters =
    "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"
    "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"
    "\xFF\xFF\x02\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x07\x06\xFF\xFF"
    "\x06\x06\x06\x06\x06\x06\x06\x06\x06\x06\x08\xFF\xFF\xFF\xFF\xFF"
    "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"
    "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\xFF\xFF\xFF\xFF"
    "\xFF\xFF\xFF\xFF\xFF\xFF\x04\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x05\xFF"
    "\xFF\xFF\xFF\xFF\x03\xFF\xFF\xFF\xFF\xFF\xFF\x01\xFF\xFF\xFF\xFF";

// JSON-significant character constants used by JSON readers.

/// Character `\t`.
const int $tab = 0x09;

/// Character `\n`.
const int $nl = 0x0a;

/// Character `\r`.
const int $cr = 0x0d;

/// Character space.
const int $space = 0x20;

/// Character `0`.
const int $0 = 0x30;

/// Character `a`.
const int $a = 0x61;

/// Character `b`.
const int $b = 0x62;

/// Character `\`.
const int $backslash = 0x5C;

/// Character `:`.
const int $colon = 0x3A;

/// Character `,`.
const int $comma = 0x2C;

/// Character `.`.
const int $dot = 0x2E;

/// Character `3`.
const int $e = 0x65;

/// Character `f`.
const int $f = 0x66;

/// Character `{`.
const int $lbrace = 0x7B;

/// Character `[`.
const int $lbracket = 0x5B;

/// Character `-`.
const int $minus = 0x2D;

/// Character `n`.
const int $n = 0x6e;

/// Character `+`.
const int $plus = 0x2B;

/// Character `"`.
const int $quot = 0x22;

/// Character `r`.
const int $r = 0x72;

/// Character `}`.
const int $rbrace = 0x7D;

/// Character `]`.
const int $rbracket = 0x5D;

/// Character `/`.
const int $slash = 0x2F;

/// Character `t`.
const int $t = 0x74;

/// Character `u`.
const int $u = 0x75;

/// Character `z`.
const int $z = 0x7a;
