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
import "dart:typed_data";

import "package:test/test.dart";
import "package:jsontool/jsontool.dart";

void main() {
  for (var kind in ["string", "utf8", "object"]) {
    group(kind, () {
      var reader = {
        "string": mkStringReader,
        "utf8": mkByteReader,
        "object": mkObjectReader,
      }[kind]!;
      testReader(reader);
    });
  }

  test("StringSlice", () {
    var slice = StringSlice("abcdefghijklmnop", 4, 12);
    expect(slice.length, 8);
    expect(slice.toString(), "efghijkl");
    expect(slice.substring(2, 6), "ghij");

    expect(slice.indexOf("kl"), 6);
    expect(slice.indexOf("kl", 4), 6);
    expect(slice.indexOf("kl", 4, 7), -1);
    expect(slice.indexOf("ef"), 0);
    expect(slice.indexOf("ef", 1), -1);
    expect(slice.indexOf("klm"), -1);

    expect(slice.contains("kl"), true);
    expect(slice.contains("klm"), false);

    var subslice = slice.subslice(2, 6);
    expect(subslice.length, 4);
    expect(subslice.toString(), "ghij");
  });
}

void testReader(JsonReader read(String source)) {
  test("parse int", () {
    var g1 = read("42");
    expect(g1.expectInt(), 42);
    var g2 = read("-42");
    expect(g2.expectInt(), -42);
    var g3 = read("true");
    expect(() => g3.expectInt(), throwsFormatException);
  });
  test("parse num", () {
    var g1 = read("42");
    expect(g1.expectNum(), same(42));
    var g2 = read("-42.55e+1");
    expect(g2.expectNum(), -425.5);
    var g3 = read("true");
    expect(() => g3.expectNum(), throwsFormatException);
  });
  test("parse double", () {
    var g1 = read("42");
    expect(g1.expectDouble(), same(42.0));
    var g2 = read("-42.55e+1");
    expect(g2.expectDouble(), -425.5);
    var g3 = read("true");
    expect(() => g3.expectDouble(), throwsFormatException);
  });
  test("parse bool", () {
    var g1 = read("true");
    expect(g1.expectBool(), true);
    var g2 = read("false");
    expect(g2.expectBool(), false);
    var g3 = read("42");
    expect(() => g3.expectBool(), throwsFormatException);
  });
  test("parse string", () {
    var g1 = read(r'"a"');
    expect(g1.expectString(), "a");
    var g2 = read(r'""');
    expect(g2.expectString(), "");
    var g2a = read(r'"\n"');
    expect(g2a.expectString(), "\n");
    var g3 = read(r'"\b\t\n\r\f\\\"\/\ufffd"');
    expect(g3.expectString(), "\b\t\n\r\f\\\"/\ufffd");
  });

  test("parse array", () {
    var g1 = read(r'[12, "str", true]');
    g1.expectArray();
    expect(g1.hasNext(), true);
    expect(g1.expectInt(), 12);
    expect(g1.hasNext(), true);
    expect(g1.expectString(), "str");
    expect(g1.hasNext(), true);
    expect(g1.expectBool(), true);
    expect(g1.hasNext(), false);
  });

  test("parse array empty", () {
    var g1 = read(r'[]');
    g1.expectArray();
    expect(g1.hasNext(), false);
  });

  test("parse array nested", () {
    var g1 = read(r'[[12, 13], [], ["str", ["str2"]], 1]');
    g1.expectArray(); // [
    expect(g1.hasNext(), true);
    g1.expectArray(); // [[
    expect(g1.hasNext(), true); // [[
    expect(g1.expectInt(), 12);
    expect(g1.hasNext(), true); // [[,
    expect(g1.expectInt(), 13);
    expect(g1.hasNext(), false); // [[,]
    expect(g1.hasNext(), true); // [[,],
    g1.expectArray(); // [[,],[
    expect(g1.hasNext(), false); // [[,],[]
    expect(g1.hasNext(), true); // [[,],[],
    g1.expectArray(); // [[,],[], [
    expect(g1.hasNext(), true);
    expect(g1.expectString(), "str");
    g1.endArray(); // [[,],[], [...]
    expect(g1.hasNext(), true); // [[,],[], [...],
    expect(g1.expectInt(), 1);
    expect(g1.hasNext(), false); // [[,],[], [...],]
  });

  test("parse object using nextKey", () {
    var g1 = read(r' { "a": true, "b": 42 } ');
    g1.expectObject();
    expect(g1.nextKey(), "a");
    expect(g1.expectBool(), true);
    expect(g1.nextKey(), "b");
    expect(g1.expectInt(), 42);
    expect(g1.nextKey(), null);
  });

  test("parse object using hasNextKey", () {
    var g1 = read(r' { "a": true, "b": 42 } ');
    g1.expectObject();
    expect(g1.hasNextKey(), true);
    expect(g1.nextKey(), "a");
    expect(g1.expectBool(), true);
    expect(g1.hasNextKey(), true);
    expect(g1.nextKey(), "b");
    expect(g1.expectInt(), 42);
    expect(g1.hasNextKey(), false);
  });

  test("parse empty object", () {
    var g1 = read(r' { } ');
    g1.expectObject();
    expect(g1.nextKey(), null);
  });

  test("parse nested object", () {
    var g1 = read(r' { "a" : {"b": true}, "c": { "d": 42 } } ');
    g1.expectObject();
    expect(g1.nextKey(), "a");
    g1.expectObject();
    expect(g1.hasNextKey(), true);
    expect(g1.nextKey(), "b");
    expect(g1.expectBool(), true);
    expect(g1.hasNextKey(), false);
    expect(g1.nextKey(), "c");
    g1.expectObject();
    expect(g1.nextKey(), "d");
    expect(g1.expectInt(), 42);
    expect(g1.nextKey(), null);
    expect(g1.nextKey(), null);
  });

  test("whitepsace", () {
    var ws = " \n\r\t";
    // JSON: {"a":[1,2.5]}  with all whitespaces between all tokens.
    var g1 = read('$ws{$ws"a"$ws:$ws[${ws}1$ws,${ws}2.5$ws]$ws}');
    g1.expectObject();
    expect(g1.hasNextKey(), true);
    expect(g1.nextKey(), "a");
    g1.expectArray();
    expect(g1.hasNext(), true);
    expect(g1.expectInt(), 1);
    expect(g1.hasNext(), true);
    expect(g1.expectDouble(), 2.5);
    expect(g1.hasNext(), false);
    expect(g1.nextKey(), null);
  });

  test("peekKey", () {
    var g1 = read(r'{"a": 42, "abe": 42, "abc": 42, "b": 42}');
    const candidates = <String>["a", "abc", "abe"]; // Sorted.
    g1.expectObject();
    expect(g1.tryKey(candidates), same("a"));
    expect(g1.expectInt(), 42);
    expect(g1.tryKey(candidates), same("abe"));
    expect(g1.expectInt(), 42);
    expect(g1.tryKey(candidates), same("abc"));
    expect(g1.expectInt(), 42);
    expect(g1.tryKey(candidates), null);
    expect(g1.nextKey(), "b");
    expect(g1.expectInt(), 42);
    expect(g1.tryKey(candidates), null);
    expect(g1.nextKey(), null);
  });

  test("skipAnyValue", () {
    var g1 = read(r'{"a":[[[[{"a":2}]]]],"b":2}');
    g1.expectObject();
    expect(g1.nextKey(), "a");
    g1.skipAnyValue();
    expect(g1.nextKey(), "b");
    expect(g1.expectInt(), 2);
    expect(g1.nextKey(), null);
  });

  test("expectAnyValue", () {
    var g1 = read(r'{"a":["test"],"b":2}');
    g1.expectObject();
    var key = g1.nextKeySource();
    var skipped = g1.expectAnyValueSource();
    expect(g1.nextKey(), "b");
    expect(g1.expectInt(), 2);
    expect(g1.nextKey(), null);

    if (g1 is JsonReader<StringSlice>) {
      expect(key.toString(), r'"a"');
      expect(skipped.toString(), r'["test"]');
    } else if (g1 is JsonReader<Uint8List>) {
      expect(key, r'"a"'.codeUnits);
      expect(skipped, r'["test"]'.codeUnits);
    } else {
      expect(key, "a");
      expect(skipped, ["test"]);
    }
  });

  test("Skip object entry", () {
    var g1 = read(r'[{"a":["test"],"b":42,"c":"str"},37]');
    g1.expectArray();
    expect(g1.hasNext(), true);
    g1.expectObject();
    expect(g1.tryKey(["a", "c"]), "a");
    g1.skipAnyValue();
    expect(g1.tryKey(["a", "c"]), null);
    expect(g1.skipObjectEntry(), true);
    expect(g1.tryKey(["a", "c"]), "c");
    g1.skipAnyValue();
    expect(g1.tryKey(["a", "c"]), null);
    expect(g1.skipObjectEntry(), false);
    expect(g1.hasNext(), true);
    expect(g1.expectInt(), 37);
    expect(g1.hasNext(), false);
  });

  test("copy", () {
    var g1 = read(r'{"a": 1, "b": {"c": ["d"]}, "c": 2}');
    expect(g1.tryObject(), true);
    expect(g1.nextKey(), "a");
    expect(g1.expectInt(), 1);
    expect(g1.nextKey(), "b");
    var g2 = g1.copy();
    expect(g1.checkObject(), true);
    g1.skipAnyValue();
    expect(g1.nextKey(), "c");
    expect(g1.expectInt(), 2);
    expect(g1.nextKey(), null);

    expect(g2.tryObject(), true);
    expect(g2.nextKey(), "c");
    expect(g2.tryArray(), true);
    expect(g2.hasNext(), true);
    expect(g2.expectString(), "d");
    expect(g2.hasNext(), false);
    expect(g2.nextKey(), null);

    expect(g2.nextKey(), "c");
    expect(g2.expectInt(), 2);
    expect(g2.nextKey(), null);
  });

  group("validating reader,", () {
    test("non-composite", () {
      var reader = read('"x"');
      var validator = validateJsonReader(reader);
      expectValue(validator);
      expect(validator.tryString(), "x");
      expectDone(validator);
    });

    test("object first", () {
      var reader = read('{"x":[1, 2.5, true], "y": 1, "z": 2}');
      var validator = validateJsonReader(reader);

      // Expect value, not inside array or object.
      expectValue(validator);
      expect(validator.tryObject(), true);
      expectKey(validator);
      expect(validator.nextKey(), "x");
      expectValue(validator, insideObject: true);
      expect(validator.tryArray(), true);
      expectHasNext(validator, insideObject: true);
      expect(validator.hasNext(), true);
      expectValue(validator, insideArray: true, insideObject: true);
      expect(validator.tryInt(), 1);
      expectHasNext(validator, insideObject: true);
      validator.endArray();
      expectKey(validator);
      expect(validator.nextKey(), "y");
      expectValue(validator, insideObject: true);
      validator.endObject();
      expectDone(validator);
    });

    test("array first", () {
      var reader = read('[{"x":[1, 2.5, true], "y": 1, "z": 2}]');
      var validator = validateJsonReader(reader);

      // Expect value, not inside array or object.
      expectValue(validator);
      expect(validator.tryArray(), true);
      expectHasNext(validator);
      expect(validator.hasNext(), true);
      expectValue(validator, insideArray: true);
      expect(validator.tryObject(), true);
      expectKey(validator, insideArray: true);
      expect(validator.nextKey(), "x");
      expectValue(validator, insideArray: true, insideObject: true);
      expect(validator.tryArray(), true);
      expectHasNext(validator, insideObject: true);
      expect(validator.hasNext(), true);
      expectValue(validator, insideArray: true, insideObject: true);
      expect(validator.tryInt(), 1);
      expectHasNext(validator, insideObject: true);
      validator.endArray();
      expectKey(validator, insideArray: true);
      expect(validator.nextKey(), "y");
      expectValue(validator, insideArray: true, insideObject: true);
      validator.endObject();
      expectHasNext(validator);
      expect(validator.hasNext(), false);
      expectDone(validator);
    });
  });

  test("String candidates", () {
    var reader = read('{"a": "b", "c": "d"}');
    var keys2 = ["a", "c"];
    var values2 = ["b", "d"];
    reader.expectObject();
    expect(reader.tryKey(values2), null);
    expect(reader.tryKey(keys2), same("a"));
    expect(reader.tryString(keys2), null);
    expect(reader.tryString(values2), same("b"));
    expect(reader.tryKey(keys2), same("c"));
    expect(reader.expectString(values2), same("d"));
    reader.endObject();
  });

  test("String candidates longer", () {
    var reader = read('{"aaa": "aab", "aac": "aad"}');
    var keys2 = ["aaa", "aac"];
    var values2 = ["aab", "aad"];
    reader.expectObject();
    expect(reader.tryKey(values2), null);
    expect(reader.tryKey(keys2), same("aaa"));
    expect(reader.tryString(keys2), null);
    expect(reader.tryString(values2), same("aab"));
    expect(reader.tryKey(keys2), same("aac"));
    expect(reader.expectString(values2), same("aad"));
    reader.endObject();
  });

  test("String candidates similar suffix", () {
    var reader = read('{"aab": "aab"}');
    var strings = ["aac", "bab"];
    var correct = ["aab"];
    reader.expectObject();
    expect(reader.tryKey(strings), null);
    expect(reader.tryKey(correct), same("aab"));
    expect(reader.tryString(strings), null);
    expect(reader.tryString(correct), same("aab"));
    reader.endObject();
  });
}

JsonReader mkStringReader(String source) => JsonReader.fromString(source);
JsonReader mkByteReader(String source) =>
    JsonReader.fromUtf8(utf8.encode(source) as Uint8List);
JsonReader mkObjectReader(String source) =>
    JsonReader.fromObject(jsonDecode(source));

// Methods used to test validating reader.
void expectNoValue(JsonReader validator) {
  expect(() => validator.checkString(), throwsStateError);
  expect(() => validator.tryString(), throwsStateError);
  expect(() => validator.expectString(), throwsStateError);
  expect(() => validator.checkArray(), throwsStateError);
  expect(() => validator.tryArray(), throwsStateError);
  expect(() => validator.expectArray(), throwsStateError);
  expect(() => validator.checkObject(), throwsStateError);
  expect(() => validator.tryObject(), throwsStateError);
  expect(() => validator.expectObject(), throwsStateError);
  expect(() => validator.expectAnyValue(nullJsonSink), throwsStateError);
  expect(() => validator.expectAnyValueSource(), throwsStateError);
}

void expectNoKey(JsonReader validator) {
  expect(() => validator.nextKey(), throwsStateError);
  expect(() => validator.tryKey(["a"]), throwsStateError);
  expect(() => validator.skipObjectEntry(), throwsStateError);
}

void expectNoHasNext(JsonReader validator) {
  expect(() => validator.hasNext(), throwsStateError);
}

void expectValue(JsonReader validator,
    {bool insideArray = false, bool insideObject = false}) {
  expectNoHasNext(validator);
  expectNoKey(validator);
  if (!insideArray) {
    expect(() => validator.endArray(), throwsStateError);
  }
  if (!insideObject) {
    expect(() => validator.endObject(), throwsStateError);
  }
}

void expectKey(JsonReader validator, {bool insideArray = false}) {
  expectNoHasNext(validator);
  if (!insideArray) {
    expect(() => validator.endArray(), throwsStateError);
  }
  expectNoValue(validator);
}

void expectHasNext(JsonReader validator, {bool insideObject = false}) {
  expectNoValue(validator);
  expectNoKey(validator);
  if (!insideObject) {
    expect(() => validator.endObject(), throwsStateError);
  }
}

void expectDone(JsonReader validator) {
  expectNoHasNext(validator);
  expectNoValue(validator);
  expectNoKey(validator);
}
