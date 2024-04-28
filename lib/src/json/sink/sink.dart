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

import 'dart:convert';

import 'byte_writer.dart';
import "null_sink.dart";
import "object_writer.dart";
import "sink_validator.dart";
import "string_writer.dart";

/// A generalized JSON visitor interface.
///
/// A JSON-like object structure (or just "JSON structure")
/// is a recursive structure of either atomic values:
///
/// * number
/// * string
/// * boolean
/// * null
///
/// or composte structures which are either
/// an *array* of one or more JSON structures,
/// or an *object* with pairs of string keys and
/// JSON structure values.
///
/// A [JsonSink] expects its members to be called in sequences
/// corresponding to the JSON structure of a single value:
/// Either a primitive value, [addNumber], [addString], [addBool] or [addNull],
/// or a [startArray] followed by JSON values and ended by an [endArray],
/// or a [startObject] followed by alternating [addKey] and values, and ended
/// with an [endObject].
///
/// In general, a [JsonSink] is not required or expected to
/// work correctly if calls are performed out of order.
/// Only call sequences corresponding to a correct JSON structure
/// are guaranteed to give a meaningful result.
abstract interface class JsonSink {
  /// Called for a number value.
  void addNumber(num value);

  /// Called for a null value.
  void addNull();

  /// Called for a string value.
  void addString(String value);

  /// Called for a boolean value.
  void addBool(bool value);

  /// Called at the beginning of an array value.
  ///
  /// Each value added until a corresponding [endArray]
  /// is considered an element of this array, unless it's part of a nested
  /// array or object.
  void startArray();

  /// Ends the current array.
  ///
  /// The array value is now complete, and should
  /// be treated as a value of a surrounding array or object.
  void endArray();

  /// Called at the beginning of an object value.
  ///
  /// Each value added until a corresponding [endObject]
  /// is considered an entry value of this object, unless it's part of a nested
  /// array or object.
  /// Each such added value must be preceded by exactly one call to [addKey]
  /// which provides the corresponding key.
  void startObject();

  /// Sets the key for the next value of an object.
  ///
  /// Should precede any value or array/object start inside an object.
  void addKey(String key);

  /// Ends the current object.
  ///
  /// The object value is now complete, and should
  /// be treated as a value of a surrounding array or object.
  void endObject();
}

/// A JSON sink which emits JSON source or JSON-like structures.
///
/// The [addSourceValue] method injects the representation of a value directly
/// as the target type [T], e.g., `String` or `List<int>` depending
/// no what is being written to. Can be used with the value of
/// [JsonReader.expectAnyValueSource] to avoid parsing a value.
abstract class JsonWriter<T> implements JsonSink {
  /// Adds a JSON value *as source* to the sink.
  ///
  /// Can be used where any of the `add` methods, like [addNumber],
  /// would add a value.
  /// The [source] becomes the next value. If the source object
  /// does not have a correct format for a JSON value,
  /// the result might be invalid, or require using
  /// [JsonReader.expectAnyValueSource] to read back.
  void addSourceValue(T source);
}

/// Creates a [JsonSink] which builds a JSON string.
///
/// The string is written to [sink].
///
/// If [indent] is supplied, the resulting string will be "pretty printed"
/// with array and object entries on lines of their own
/// and indented by multiples of the [indent] string.
/// If the [indent] string is not valid JSON whitespace,
/// the result written to [sink] will not be valid JSON source.
///
/// If [asciiOnly] is set to `true`, string values will have all non-ASCII
/// characters escaped. If not, only control characters, quotes and backslashes
/// are escaped.
///
/// The returned sink is not reusable. After it has written a single JSON
/// structure, it should not be used again.
JsonWriter<String> jsonStringWriter(StringSink sink,
    {String? indent, bool asciiOnly = false}) {
  if (indent == null) return JsonStringWriter(sink, asciiOnly: asciiOnly);
  return JsonPrettyStringWriter(sink, indent, asciiOnly: asciiOnly);
}

/// Creates a [JsonSink] which builds a byte representation of the JSON
/// structure.
///
/// The bytes are written to [sink], which is closed when a complete JSON
/// value / object structure has been written.
///
/// If [asciiOnly] is true, string values will escape any non-ASCII
/// character. If false or unspecified and [encoding] is [utf8], only
/// control characters are escaped.
///
/// The resulting byte representation is a minimal JSON text with no
/// whitespace between tokens.
JsonWriter<List<int>> jsonByteWriter(Sink<List<int>> sink,
    {Encoding encoding = utf8, bool? asciiOnly}) {
  return JsonByteWriter(sink, encoding: encoding, asciiOnly: false);
}

/// Creates a [JsonSink] which builds a Dart JSON object structure.
///
/// After adding values corresponding to a JSON structure to the sink,
/// the [result] callback is called with the resulting object structure.
///
/// When [result] is called, the returned sink is reset and can be reused.
JsonWriter<Object?> jsonObjectWriter(void Function(Object?) result) =>
    JsonObjectWriter(result);

/// Wraps a [JsonSink] in a validating layer.
///
/// A [JsonSink] is an API which requires methods to be called in a specific
/// order, but implementations are allowed to not check this.
/// Calling methods in an incorrect order may throw,
/// or it may return spurious values.
///
/// The returned sink wraps [sink] and intercepts all method calls.
/// It throws immediately if the calls are not in a proper order.
///
/// This function is mainly intended for testing code which writes to
/// sinks, to ensure that they make calls in the
///
/// If [allowReuse] is set to true, the sink is assumed to be *reusable*,
/// meaning that after completely writing a JSON structure, it resets
/// and accepts following JSON structures. If not, then no method
/// may be called after completing a single JSON structure.
JsonSink validateJsonSink(JsonSink sink, {bool allowReuse = false}) {
  return ValidatingJsonSink(sink, allowReuse);
}

/// A [JsonSink] which accepts any calls and ignores them.
///
/// Can be used if a sink is needed, but the result of the sink
/// operations is not important.
const JsonSink nullJsonSink = NullJsonSink();

/// Interface which classes that write themselves to [JsonSink]s can implement.
abstract interface class JsonWritable {
  /// Writes a JSON representation of this object to [target].
  void writeJson(JsonSink target);
}

extension JsonWritableAddWritable on JsonSink {
  /// Writes [writable] to this sink.
  ///
  /// Convenience function to allow doing `writable.writeJson(sink)`
  /// inside a sequence cascade calls on the sink.
  void addWritable(JsonWritable writable) {
    writable.writeJson(this);
  }
}

/// Convenience functions for adding object properties to a [JsonSink].
///
/// For hand-written code that adds values to a [JsonSink].
extension JsonSinkAddEntry on JsonSink {
  /// Adds a key and string value entry to the current JSON object.
  ///
  /// Same as calling [JsonSink.addKey] followed by [JsonSink.addString].
  void addStringEntry(String key, String value) {
    this
      ..addKey(key)
      ..addString(value);
  }

  /// Adds a key and boolean value entry to the current JSON object.
  ///
  /// Same as calling [JsonSink.addKey] followed by [JsonSink.addBool].
  void addBoolEntry(String key, bool value) {
    this
      ..addKey(key)
      ..addBool(value);
  }

  /// Adds a key and number value entry to the current JSON object.
  ///
  /// Same as calling [JsonSink.addKey] followed by [JsonSink.addNumber].
  void addNumberEntry(String key, num value) {
    this
      ..addKey(key)
      ..addNumber(value);
  }

  /// Adds a key and writable value entry to the current JSON object.
  ///
  /// Same as calling [JsonSink.addKey] followed by
  /// [JsonWritableAddWritable.addWritable].
  void addWritableEntry(String key, JsonWritable value) {
    this.addKey(key);
    value.writeJson(this);
  }
}
