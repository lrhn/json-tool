// Copyright 2021 Google LLC
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

/// An example of how to read JSON numbers into custom number types.
///
/// Here integers are parsed into [BigInt] and floating points are
/// kept as doubles.
/// Choosing other representations is a matter of adapting the
/// `processNum`/`processUnknown` overrides in the [JsonProcessor]
/// sub-classes.
library;

import "package:jsontool/jsontool.dart";

/// Parses a JSON string into JSON-like object structure.
///
/// Like normal JSON parsing except the all integers are represented
/// by [BigInt] values.
Object? parseBigIntJson(String source) {
  Object? value;
  _BigIntJsonReader((result) {
    value = result;
  }).processValue(JsonReader.fromString(source));
  return value;
}

/// Converts a JSON-like object structure to a string.
///
/// Any [BigInt] values are written into the result as number literals.
String serializeBigIntJson(Object? value, {String? indent}) {
  var buffer = StringBuffer();
  var serializer = _BigIntJsonWriter(buffer, indent);
  serializer.processValue(JsonReader.fromObject(value));
  return buffer.toString();
}

final class _BigIntJsonWriter
    extends JsonSinkProcessor<JsonReader<Object?>, JsonWriter<String>> {
  _BigIntJsonWriter(StringSink sink, String? indent)
      : super(jsonStringWriter(sink, indent: indent));

  @override
  void processUnknown(JsonReader<Object?> reader, String? key) {
    // The source of a JsonReader<Object?> is the unknown object.
    var value = reader.expectAnyValueSource();
    if (value is BigInt) {
      if (key != null) sink.addKey(key);
      sink.addSourceValue(value.toString());
    } else {
      throw FormatException("Unexpected value", value);
    }
  }
}

final class _BigIntJsonReader
    extends JsonSinkProcessor<JsonReader<StringSlice>, JsonWriter<Object?>> {
  _BigIntJsonReader(void Function(Object?) resultCallback)
      : super(jsonObjectWriter(resultCallback));

  @override
  void processNum(JsonReader<StringSlice> reader, String? key) {
    if (key != null) sink.addKey(key);
    var source = reader.expectAnyValueSource().toString();
    assert(source.isNotEmpty);
    var result = BigInt.tryParse(source);
    if (result != null) {
      sink.addSourceValue(result);
      return;
    }
    sink.addNumber(double.parse(source));
  }
}

void main() {
  // Start with a JSON containing a number too big for Dart integers.
  var source = '{"x":123456789123456789123456789123456789}';
  print("source: $source");
  var data = parseBigIntJson(source) as Map<String, Object?>;
  print("big value: ${data["x"]}"); // The big integer.
  var newSource = serializeBigIntJson(data);
  print("new source: $newSource"); // Roundtripped.
  assert(source == newSource);
}
