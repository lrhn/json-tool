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

import "dart:convert";
import 'dart:io';
import 'dart:typed_data';

import "package:jsontool/jsontool.dart";
import "package:test/test.dart";

import "src/json_data.dart";

void main() {
  test("simple rebuild", () {
    var simple = jsonDecode(simpleJson);
    Object? builtSimple;
    JsonReader.fromString(simpleJson).expectAnyValue(jsonObjectWriter((result) {
      builtSimple = result;
    }));
    expect(simple, builtSimple);
  });

  test("simple toString", () {
    var simple = jsonEncode(jsonDecode(simpleJson));
    var buffer = StringBuffer();
    JsonReader.fromString(simpleJson).expectAnyValue(jsonStringWriter(buffer));
    expect(simple, buffer.toString());
  });

  group('jsonObjectWriter', () {
    Object? result;
    setUp(() => result = null);

    testJsonSink(
      createSink: () => jsonObjectWriter((out) => result = out),
      parsedResult: () => jsonEncode(result),
    );
  });

  group('jsonStringWriter', () {
    var buffer = StringBuffer();
    setUp(() => buffer.clear());

    testJsonSink(
      createSink: () => jsonStringWriter(buffer),
      parsedResult: () => buffer.toString(),
    );
  });

  group('jsonByteWriter', () {
    var builder = BytesBuilder();
    setUp(() => builder.clear());

    testJsonSink(
      createSink: () =>
          jsonByteWriter(ByteConversionSink.withCallback(builder.add)),
      parsedResult: () => utf8.decode(builder.toBytes()),
    );
  });

  group("validating sink,", () {
    test("single value", () {
      var sink = validateJsonSink(nullJsonSink);
      expectValue(sink);
      sink.addNumber(1);
      expectDone(sink);
    });
    test("single value, reusable", () {
      var sink = validateJsonSink(nullJsonSink, allowReuse: true);
      expectValue(sink);
      sink.addNumber(1);
      expectValue(sink);
      sink.addString("x");
    });
    test("composite", () {
      var sink = validateJsonSink(nullJsonSink);
      expectValue(sink);
      sink.startArray();
      expectValue(sink, insideArray: true);
      sink.addString("x");
      expectValue(sink, insideArray: true);
      sink.startObject();
      expectKey(sink);
      sink.addKey("x");
      expectValue(sink);
      sink.startArray();
      expectValue(sink, insideArray: true);
      sink.endArray();
      expectKey(sink);
      sink.endObject();
      expectValue(sink, insideArray: true);
      sink.endArray();
      expectDone(sink);
    });
  });
}

void testJsonSink({
  required JsonSink Function() createSink,
  required String Function() parsedResult,
}) {
  test('simple', () {
    JsonReader.fromString(simpleJson).expectAnyValue(createSink());
    var simple = jsonEncode(jsonDecode(simpleJson));
    expect(parsedResult(), simple);
  });

  test('complex', () {
    var complex = jsonEncode(jsonDecode(complexJson));
    JsonReader.fromString(complexJson).expectAnyValue(createSink());
    expect(parsedResult(), complex);
  });
}

// Utility functions for checking validating sink.
void expectNoKey(JsonSink sink) {
  expect(() => sink.addKey("a"), throwsStateError);
}

void expectNoValue(JsonSink sink) {
  expect(() => sink.addBool(true), throwsStateError);
  expect(() => sink.addNull(), throwsStateError);
  expect(() => sink.addNumber(1), throwsStateError);
  expect(() => sink.addString(""), throwsStateError);
  expect(() => sink.startArray(), throwsStateError);
  expect(() => sink.startObject(), throwsStateError);
}

void expectKey(JsonSink sink) {
  expectNoValue(sink);
  expect(() => sink.endArray(), throwsStateError);
}

void expectValue(JsonSink sink, {bool insideArray = false}) {
  expectNoKey(sink);
  expect(() => sink.endObject(), throwsStateError);
  if (!insideArray) {
    expect(() => sink.endArray(), throwsStateError);
  }
}

void expectDone(JsonSink sink) {
  expectNoValue(sink);
  expectNoKey(sink);
  expect(() => sink.endObject(), throwsStateError);
  expect(() => sink.endArray(), throwsStateError);
}
