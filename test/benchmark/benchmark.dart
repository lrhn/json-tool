// Copyright 2024 Google LLC
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

import "dart:convert";

import "package:jsontool/jsontool.dart";
import "package:jsontool/src/json/sink/null_sink.dart";

import "../src/json_data.dart";

void main() {
  benchByteReader();
  benchStringReader();
}

void benchByteReader() {
  _benchByteReader(100);
  for (var i = 0; i < 3; i++) {
    _benchByteReader(1500);
  }
}

void _benchByteReader(int limit) {
  var inputUtf8 = utf8.encode(complexJson);
  var sink = NullJsonSink();
  var reader = JsonReader.fromUtf8(inputUtf8);

  var c = 0;
  var e = 0;
  var n = 100;
  var sw = Stopwatch()..start();
  do {
    for (var i = 0; i < n; i++) {
      reader.copy().expectAnyValue(sink);
    }
    e = sw.elapsedMilliseconds;
    c += n;
    n *= 2;
  } while (e < limit);

  if (limit >= 200) {
    print("UTF-8 JsonReader: ${(c / e).toStringAsFixed(3)} parses/ms");
  }
}

void benchStringReader() {
  _benchStringReader(100);
  for (var i = 0; i < 3; i++) {
    _benchStringReader(1500);
  }
}

void _benchStringReader(int limit) {
  var input = complexJson;
  var sink = NullJsonSink();
  var reader = JsonReader.fromString(input);

  var c = 0;
  var e = 0;
  var n = 100;
  var sw = Stopwatch()..start();
  do {
    for (var i = 0; i < n; i++) {
      reader.copy().expectAnyValue(sink);
    }
    e = sw.elapsedMilliseconds;
    c += n;
    n *= 2;
  } while (e < limit);

  if (limit >= 200) {
    print("String JsonReader: ${(c / e).toStringAsFixed(3)} parses/ms");
  }
}
