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

// JSON-significant character constants used by JSON readers.

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
