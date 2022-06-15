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

// A generalized processor for JSON source which takes elements from a
// reader, then leaves the processing to user overridable methods.

import "../reader/reader.dart";
import "../sink/sink.dart";

/// A generalized JSON processor.
///
/// The processor traverses JSON-like data as provided by a [JsonReader].
/// It dispatches to individual `process` methods for each
/// kind of JSON value, but doesn't process the value
/// by default.
/// These methods can be overridden in subclasses to do something useful.
/// For example, the [JsonSinkProcessor] defaults to forwarding
/// each kind of JSON data to a [JsonSink].
///
/// The processor is similar to a [JsonSink]
/// in that there are methods for each kind of JSON data,
/// but instead of passing the JSON values to the individual `add` methods,
/// the `process` methods of the processsor takes a reader
/// which is ready to provide the value.
///
/// The process-method can either read the value, skip it,
/// or even read the source using [JsonReader.expectAnyValueSource]
/// and handle it itself.
///
/// Each process-method takes a `key` which is non-null when the
/// value is a JSON-object value. This allows the processor
/// to easily skip entire entries, perhaps even based on the
/// key name.
///
/// An example implementation of [processNum] could be:
/// ```dart
///   void processNum(JsonReader reader, String? key) {
///     if (key != null && key.startsWith("x-")) {
///       // Ignore key and value.
///       reader.skipAnyValue();
///     } else {
///       // Add key and value to a JsonSink.
///       if (key != null) sink.addKey(key);
///       sink.addNumber(reader.expectNum());
///     }
///   }
/// ```
abstract class JsonProcessor<Reader extends JsonReader> {
  /// Process a JSON-value.
  ///
  /// Dispatches to one of [processNull], [processNum],
  /// [processString], [processBool], [processArray]
  /// or [processObject] depending on what the next
  /// value of the reader is.
  /// If there is no value, or the reader has values
  /// which do not match a JSON type, the [processUnkown]
  /// method is called instead. This allows handling of
  /// unknown values in readers supporting that.
  void processValue(Reader reader, [String? key]) {
    if (reader.checkArray()) {
      if (processArray(reader, key)) {
        while (reader.hasNext()) {
          processValue(reader);
        }
        endArray(key);
      }
    } else if (reader.checkObject()) {
      if (processObject(reader, key)) {
        var elementKey = reader.nextKey();
        while (elementKey != null) {
          processValue(reader, elementKey);
          elementKey = reader.nextKey();
        }
        endObject(key);
      }
    } else if (reader.checkString()) {
      processString(reader, key);
    } else if (reader.checkNum()) {
      processNum(reader, key);
    } else if (reader.checkBool()) {
      processBool(reader, key);
    } else if (reader.checkNull()) {
      processNull(reader, key);
    } else {
      processUnknown(reader, key);
    }
  }

  /// Invoked for a reader which has no value or an unrecognized value.
  ///
  /// A reader for malformed input may have no value where one is expected,
  /// and a reader of an object structure may have a value which isn't
  /// one of the JSON values. This method is called in those cases.
  ///
  /// If [key] is non-null, it's the key of the value in the current object.
  /// The key is always `null` outside of an object.
  ///
  /// Defaults to throwing.
  void processUnknown(Reader reader, String? key) {
    throw StateError("No value");
  }

  /// Called when the reader encounters the start of a JSON object.
  ///
  /// Returns whether to continue processing the contents of
  /// the object.
  ///
  /// This call should either consume the object start
  /// (using `reader.expectObject()`) and return `true`,
  /// or consume the entire object value (e.g., using `reader.skipAnyValue()`)
  /// and return `false`.
  /// The default implementation does the former.
  ///
  /// If returning `true`, the processor will continue to
  /// process pairs of keys and values, and finish by calling
  /// [endObject] when there are no further entries.
  ///
  /// If [key] is non-null, it's the key of the value in the current object.
  /// The key is always `null` outside of an object.
  bool processObject(Reader reader, String? key) {
    reader.expectObject();
    return true;
  }

  /// Called after all key/value pairs of the current object are processed.
  ///
  /// If [key] is non-null, it's the key of the completed value
  /// in the current object. This is the same key as passed to the corresponding
  /// [processObject] call.
  /// The key is always `null` outside of an object.
  void endObject(String? key) {}

  /// Called when the reader encounters a JSON array.
  ///
  /// Returns whether to continue processing the contents of
  /// the array.
  ///
  /// This call should either consume the array start
  /// (using `reader.expectArray()`) and return `true`,
  /// or consume the entire array (e.g., using `reader.skipAnyValue()`)
  /// and return `false`.
  /// The default implementation does the former.
  ///
  /// If returning `true`, the processor will continue to
  /// process individualk values of the array using
  /// the typed `process`-functions, and finish with
  /// [endArray] when there are no further values.
  ///
  /// If [key] is non-null, it's the key of the value in the current object.
  /// The key is always `null` outside of an object.
  bool processArray(Reader reader, String? key) {
    reader.expectArray();
    return true;
  }

  /// Called when an array has no more elements.
  ///
  /// If [key] is non-null, it's the key of the completed value
  /// in the current object. This is the same key as passed to the corresponding
  /// [startObject] call.
  /// The key is always `null` outside of an object.
  void endArray(String? key) {}

  /// Called when the next value is a `null` value.
  ///
  /// The call should consume the value, for example by `reader.expectNull()`,
  /// `reader.skipAnyValue()` or `reader.expectAnyValueSource()`.
  ///
  /// If [key] is non-null, it's the key of the value in the current object.
  /// The key is always `null` outside of an object.
  void processNull(Reader reader, String? key) {
    reader.expectNull();
  }

  /// Called when the next value is a string value.
  ///
  /// The call should consume the value, for example by `reader.expectString()`,
  /// `reader.skipAnyValue()` or `reader.expectAnyValueSource()`.
  ///
  /// If [key] is non-null, it's the key of the value in the current object.
  /// The key is always `null` outside of an object.
  void processString(Reader reader, String? key) {
    reader.expectString();
  }

  /// Called when the next value is a boolean value.
  ///
  /// The call should consume the value, for example by `reader.expectBool()`,
  /// `reader.skipAnyValue()` or `reader.expectAnyValueSource()`.
  ///
  /// If [key] is non-null, it's the key of the value in the current object.
  /// The key is always `null` outside of an object.
  void processBool(Reader reader, String? key) {
    reader.expectBool();
  }

  /// Called when the next value is a number value.
  ///
  /// The call should consume the value, for example by `reader.expectNum()`,
  /// `reader.skipAnyValue()` or `reader.expectAnyValueSource()`.
  ///
  /// If [key] is non-null, it's the key of the value in the current object.
  /// The key is always `null` outside of an object.
  void processNum(Reader reader, String? key) {
    reader.expectNum();
  }
}

/// A generalized JSON processor which forwards data to a JSON sink.
///
/// Allows individual `process` methods to be overridden for special
/// behavior, like detecting specific keys and treating values differently,
/// or detecting specific values and parsing them differently.
///
/// The default behavior of the process-methods is to call [JsonSink.addKey]
/// if the `key` is non-`null`, then expect a value and call the sink's
/// corresponding `add` method with the value.
/// Example:
/// ```dart
///   void processString(Reader reader, String? key) {
///     if (key != null) sink.addKey(key);
///     sink.addString(reader.expectString());
///   }
/// ```
/// If overridden, the overriding method should make sure to call `addKey`
/// on the sink first when the `key` is non-null, if it intends to add
/// any value (and not add the key if it intends to skip the value).
class JsonSinkProcessor<Reader extends JsonReader, Sink extends JsonSink>
    extends JsonProcessor<Reader> {
  /// The target sink.
  final Sink sink;

  /// Creat a JSON processor forwarding events to [sink].
  JsonSinkProcessor(this.sink);

  @override
  bool processObject(Reader reader, String? key) {
    if (key != null) sink.addKey(key);
    reader.expectObject();
    sink.startObject();
    return true;
  }

  @override
  void endObject(String? key) {
    sink.endObject();
  }

  @override
  bool processArray(Reader reader, String? key) {
    if (key != null) sink.addKey(key);
    reader.expectArray();
    sink.startArray();
    return true;
  }

  @override
  void endArray(String? key) {
    sink.endArray();
  }

  @override
  void processNull(Reader reader, String? key) {
    if (key != null) sink.addKey(key);
    reader.expectNull();
    sink.addNull();
  }

  @override
  void processBool(Reader reader, String? key) {
    if (key != null) sink.addKey(key);
    sink.addBool(reader.expectBool());
  }

  @override
  void processNum(Reader reader, String? key) {
    if (key != null) sink.addKey(key);
    sink.addNumber(reader.expectNum());
  }

  @override
  void processString(Reader reader, String? key) {
    if (key != null) sink.addKey(key);
    sink.addString(reader.expectString());
  }
}
