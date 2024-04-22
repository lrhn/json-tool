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

import "dart:typed_data";

import "../sink/sink.dart";
import "byte_reader.dart";
import "object_reader.dart";
import "reader_validator.dart";
import "string_reader.dart";

export "string_reader.dart" show StringSlice;

/// A JSON reader which provides pull-based access to individual JSON tokens.
///
/// A JSON reader is a low-level API for deconstructing JSON source without
/// creating unnecessary intermediate values.
/// As a low-level API, it is not attempting to provide all possible
/// conveniences, and it does not validate that it is being used
/// correctly.
/// It is possible to call methods in an order which does not correspond
/// to a valid JSON structure. The user is intended to make sure this doesn't
/// happen. (However, the [validateJsonReader] can be used to add extra
/// validation/ to a reader for testing.)
///
/// The JSON reader scans JSON source code from start to end.
/// It provides access to the next token, either an individual value or the
/// start of a JSON object or array. Inside an object or array, it allows
/// iterating through the entries or elements, or skipping to the end.
/// It also allows completely skipping the next JSON value, which recursively
/// skips objects and arrays.
///
/// * `expect` methods predict the type of the next value,
///   and throws if that kind of value is not the next found.
///   This consumes the value for non-composite values
///   and prepares for iterating elements or entries for object or arrays.
///   Examples: [expectString], [expectObject].
/// * `try` methods checks whether the next value is of the expected
///   kind, and if so, it works like the correspod `expect` method.
///   If not, the return value represents this failure in some way
///   appropriate to the return type (a `null` value if the `expect` method
///   returns a value, a boolean `true`/`false` if the `expect` method
///   is a `void` method).
///   Examples: [tryString], [tryInt], [tryArray].
/// * `check` methods checks whether the next value is of the expected
///   type, but does not consume (or parse) it.
///   There are no `checkInt` or `checkDouble` methods, only a [checkNum],
///   because distinguishing the two will require parsing.
///
/// Methods may throw a [FormatException]. If that happens, the state
/// of the reader is unspecified, and it should not be used again.
///
/// The `expect` functions will throw if the next value is not of the
/// expected kind.
/// Both `expect` and `try` functions, and the iteration functions, *may*
/// throw if the input is not valid JSON. Some errors prevent further progress,
/// others may be ignored.
/// The [check] functions never throw.
///
/// When an array has been entered using [expectArray] or [tryArray],
/// the individual elements should be iterated using [hasNext].
/// Example:
/// ```dart
/// var json = JsonReader.fromString(source);
/// // I know it's a list of strings.
/// var result = <String>[];
/// json.expectArray();
/// while (json.hasNext()) {
///   result.add(json.expectString());
/// }
/// ```
/// When [hasNext] returns true, the reader is in position to
/// read the next value in the array.
/// When [hasNext] returns false, the reader has exited the
/// array.
/// You can also stop the array iteration at any time by
/// calling [endArray]. This will ignore any further values
/// in the array and exit it.
///
/// When an object has been entered using [expectObject] or [tryObject],
/// it can be iterated using [nextKey].
/// Example:
/// ```dart
/// var json = JsonReader.fromString(source);
/// // I know it's an object with string values
/// var result = <String, String>{};
/// json.expectObject();
/// String key;
/// while ((key = json.nextKey()) != null) {
///   result[key] = json.expectString();
/// }
/// ```
/// When [nextKey] returns a string, the reader is in position to
/// read the corresponding value in the object.
/// When [nextKey] returns `null`, the reader has exited the
/// object.
/// The [tryKey] method can check the next key against a number
/// of known keys. If the next key is not one of the candidates
/// passed to the method, nothing happens. Then the [skipMapEntry]
/// method can be used to ignore the following key/value pair.
/// You can also stop the array iteration at any time by
/// calling [endObject]. This will ignore any further keys or values
/// in the object and exit it.
///
/// Correct nesting of arrays or objects is handled by the caller.
/// The reader may not maintain any state except how far it has
/// come in the input.
/// Calling methods out of order will cause unspecified behavior.
///
/// The [skipAnyValue] will skip the next value completely, even if it's
/// an object or array.
/// The [expectAnyValueSource] will skip the next value completely,
/// but return a representation of the *source* of that value
/// in a format corresponding to the original source,
/// as determined by the reader implementation.
///
/// A reader is not necessarily *validating*.
/// If the input is not valid JSON, the behavior is unspecified.
abstract interface class JsonReader<SourceSlice> {
  /// Creates a JSON reader from a string containing JSON source.
  ///
  /// Returns a [StringSlice] from [expectAnyValueSource].
  static JsonReader<StringSlice> fromString(String source) =>
      JsonStringReader(source);

  /// Creates a JSON reader from a UTF-8 encoded JSON source
  ///
  /// Returns a [Uint8List] view from [expectAnyValueSource].
  static JsonReader<Uint8List> fromUtf8(Uint8List source) =>
      JsonByteReader(source);

  /// Creates a JSON reader from a JSON-like object structure.
  ///
  /// This reader is not actually scanning JSON source code,
  /// it merely provides a similar API for accessing JSON which
  /// has already been parsed into an object structure.
  /// It may not be as efficient as the source based reader.
  /// A souce based reader, like [JsonReader.fromString] or
  /// [JsonReader.fromUtf8], is preferred when it can be used.
  ///
  /// A JSON-like object structure is either a number, string,
  /// boolean or null value, or a list of JSON-like object
  /// structures, or a map from strings to JSON-like object
  /// structures.
  ///
  /// Returns the current object from [expectAnyValueSource],
  /// whether it's JSON-like or not.
  /// If all the `check`-methods return false where a value
  /// is expected, then it's likely because a non-JSON-like
  /// object is embedded in the object structure.
  static JsonReader<Object?> fromObject(Object? source) =>
      JsonObjectReader(source);

  /// Consumes the next value which must be `null`.
  Null expectNull();

  /// Consumes the next value if it is `null`.
  ///
  /// Returns `true` if a `null` was consumed and `false` if not.
  bool tryNull();

  /// Whether the next value is null.
  bool checkNull();

  /// Consumes the next value which must be `true` or `false`.
  bool expectBool();

  /// The next value, if it is `true` or `false`.
  ///
  /// If the next value is a boolean, then it is
  /// consumed and returned.
  /// Returns `null` and does not consume anything
  /// if there is no next value or the next value
  /// is not a boolean.
  bool? tryBool();

  /// Whether the next value is a boolean.
  bool checkBool();

  /// The next value, which must be a number.
  ///
  /// The next value must be a valid JSON number.
  /// It is returned as an [int] if the number
  /// has no decimal point or exponent, otherwise
  /// as a [double] (as if parsed by [num.parse]).
  num expectNum();

  /// The next value, if it is a number.
  ///
  /// If the next value is a valid JSON number,
  /// it is returned as an [int] if the number
  /// has no decimal point or exponent, otherwise
  /// as a [double] (as if parsed by [num.parse]).
  /// Returns `null` if the next value is not a number.
  num? tryNum();

  /// Whether the next value is a number.
  bool checkNum();

  /// Return the next value which must be an integer.
  ///
  /// The next value must be a valid JSON number
  /// with no decimal point or exponent.
  /// It is returned as an [int] (as if parsed by [int.parse]).
  int expectInt();

  /// Return the next value if it is an integer.
  ///
  /// If the next value is a valid JSON number
  /// with no decimal point or exponent,
  /// it is returned as an [int] (as if parsed by [int.parse]).
  /// Returns `null` if the next value is not an integer.
  int? tryInt();

  /// The next value, which must be a number.
  ///
  /// The next value must be a valid JSON number.
  /// It is returned as a [double] (as if parsed by [double.parse]).
  double expectDouble();

  /// The next value, if it is a number.
  ///
  /// If the next value is a valid JSON number,
  /// it is returned as a [double] (as if parsed by [double.parse]).
  /// Returns `null` if the next value is not a number.
  double? tryDouble();

  /// The next value, which must be a string.
  ///
  /// If [candidates] is supplied, the next string must be one of the
  /// candidate strings.
  /// The [candidates] must be a *sorted* list of ASCII strings.
  ///
  /// Equivalent to [tryString] except that it throws where
  /// [tryString] would return `null`.
  String expectString([List<String>? candidates]);

  /// The next value, if it is a string.
  ///
  /// Returns the next value of the reader if it is a valid JSON string.
  /// Returns `null` if the next value is not a string.
  ///
  /// If [candidates] are supplied, the next string is only accepted if it
  /// is one of the strings in [candidates] *and* the string representation
  /// does not contain any escape sequences.
  /// The [candidates] *must* be a non-empty *sorted* list of ASCII
  /// strings.
  /// If the next value is one of the strings of [candidates], then the
  /// string value from [candidates] is returned, otherwise the
  /// result is `null`.
  ///
  /// Example:
  /// ```dart
  /// // Parsing the JSON text: {"type": "bool", "value": true}
  /// ...
  /// reader.expectObject();
  /// var key = reader.nextKey();
  /// if (key == "type") {
  ///   var type = reader.tryString(["bool", "int", "string"]);
  ///   if (identical(type, "bool")) {
  ///     key = reader.nextKey();
  ///     assert(key == "value");
  ///     bool value = reader.expectBool();
  ///     ...
  ///   } ...
  /// }
  /// reader.endObjet();
  /// ```
  /// Using the [candidates] parameter avoids allocating a new string
  /// if you are sure that it will have one of a small number of known
  /// values.
  String? tryString([List<String>? candidates]);

  /// Whether the next value is a string.
  bool checkString();

  /// Enters the next value, which must be an array.
  ///
  /// The array should then be iterated using [hasNext] or [endArray].
  void expectArray();

  /// Enters the next value if it is an array.
  ///
  /// Returns `true` if the reader entered an array
  /// and `false` if not.
  ///
  /// The entered array should then be iterated using
  /// [hasNext] or [endArray].
  bool tryArray();

  /// Whether the next value is an array.
  bool checkArray();

  /// Find the next array element in the current array.
  ///
  /// Must be called either after entering an array
  /// using [expectArray] or [tryArray]
  /// or after reading an array element.
  ///
  /// Returns true if there are more elements,
  /// and prepares the reader for reading the next
  /// array element. This element must then be
  /// consumed ([expectInt], etc) or skipped ([skipAnyValue])
  /// before this function can be called again.
  ///
  /// Returns false if there is no next element,
  /// and this also exits the array.
  bool hasNext();

  /// Skips the remainder of the current object.
  ///
  /// Exits the current array, ignoring any further
  /// elements.
  ///
  /// An array is "current" after entering it
  /// using [tryArray] or [expectArray],
  /// and until exiting by having [hasNext] return false
  /// or by calling [endArray].
  /// Entering another array makes that current until
  /// that array is exited.
  void endArray();

  /// Enters the next value, which must be an object.
  ///
  /// The object should then be iterated using
  /// [nextKey], [skipObjectEntry] or [endObject].
  void expectObject();

  /// Enters the next value if it is an object.
  ///
  /// Returns `true` if the reader entered an object
  /// and `false` if not.
  ///
  /// The entered object should then be iterated using
  /// [nextKey], [skipObjectEntry] or [endObject].
  bool tryObject();

  /// Whether the next value is an object.
  bool checkObject();

  /// Check whether there is a next key, close object if not.
  ///
  /// Must only be used while reading an object.
  /// If the current object has more properties,
  /// then this function returns `true` and does nothing else.
  /// The next call to [nextKey] is then guaranteed to
  /// return a string.
  ///
  /// If the current object has no more properties,
  /// then this function returns `false` *and* the object
  /// is completed as if a call to [nextKey] had returned `null`.
  ///
  /// This behavior allows for usage patterns like:
  /// ```dart
  ///   var result = <String, String>{};
  ///   while (reader.hasNextKey()) {
  ///     result[reader.nextKey()!] = reader.expectString();
  ///   }
  /// ```
  /// without needing to introduce an extra variable to hold the key
  /// and then check if the key is `null`.
  bool hasNextKey();

  /// The next key of the current object.
  ///
  /// Must only be used while reading an object.
  /// If the current object has more properties,
  /// then the key of the next property is returned,
  /// and the reader is ready to read the
  /// corresponding value.
  ///
  /// Returns `null` if there are no further entries,
  /// and exits the object.
  String? nextKey();

  /// The source of the nex key of the current object.
  ///
  /// Must only be used while reading an object.
  /// If the current object has more properties,
  /// then the source of the key of the next property is returned,
  /// and the reader is ready to read the
  /// corresponding value.
  ///
  /// This operation can be used if the key is expected to
  /// be complicated or long, and there is no need for the
  /// key as a string object. Allocating the source slice is
  /// not free either, so for short ASCII strings, it can
  /// easily be more efficient to just use [nextKey].
  /// The returned source starts at the leading quote and
  /// ends after the trailing quote of the key string.
  ///
  /// Returns `null` if there are no further entries,
  /// and exits the object.
  SourceSlice? nextKeySource();

  /// The next object key, if it is in the list of candidates.
  ///
  /// Like [nextKey] except that it only matches if the next key
  /// is one of the strings in [candidates] *and* the key string
  /// value does not contain any escapes.
  ///
  /// The [candidates] *must* be a non-empty *sorted* list of ASCII
  /// strings.
  ///
  /// This is intended for simple key strings, which is what
  /// most JSON uses.
  /// If a match is found, the string object in the [candidates] list
  /// is returned rather than creating a new string.
  String? tryKey(List<String> candidates);

  /// Skips the next map entry, if there is one.
  ///
  /// Can be used in the same situations as [nextKey] or [tryKey],
  /// but skips the key and the following value.
  ///
  /// Returns `true` if an entry was skipped.
  /// Returns `false` if there are no further entries
  /// and exits the object.
  bool skipObjectEntry();

  /// Skips the remainder of the current object.
  ///
  /// Exits the current object, ignoring any further
  /// keys or values.
  ///
  /// An object is "current" after entering it
  /// using [tryObject] or [expectObject],
  /// and until exiting by having [nextKey] return `null`
  /// or calling [endObject].
  /// Entering another object makes that current until
  /// that object is exited.
  void endObject();

  /// Skips the next value.
  ///
  /// This skips and consumes the entire next value.
  /// If the value is an array or object, all the
  /// nested elements or entries are skipped too.
  ///
  /// Example:
  /// ```dart
  /// var g = JsonGet(r'[{"a": 42}, "Here"]');
  /// g.expectArray();
  /// g.hasNext(); // true
  /// g.skipAnyValue();
  /// g.hasNext(); // true;
  /// g.expectString(); // "Here"
  /// ```
  Null skipAnyValue();

  /// Skips the next value.
  ///
  /// This skips and consumes the entire next value.
  /// If the value is an array or object, all the
  /// nested elements or entries are skipped too.
  ///
  /// Returns a representation of the source corresponding
  /// to the skipped value. The kind of value returned
  /// depends on the implementation and source format.
  ///
  /// There must be a next value.
  SourceSlice expectAnyValueSource();

  /// Skips the next value.
  ///
  /// This skips and consumes the entire next value.
  /// If the value is an array or object, all the
  /// nested elements or entries are skipped too.
  ///
  /// Parses the JSON structure of the skipped value
  /// and emits it on the [sink].
  Null expectAnyValue(JsonSink sink);

  /// Creates a copy of the state of the current reader.
  ///
  /// This can be used to, for example, create a copy,
  /// then skip a value using [skipAnyValue], and then
  /// later come back to the copy reader and read the
  /// value anyway.
  JsonReader copy();
}

/// Makes a [JsonReader] validate the order of its operations.
///
/// The methods of a reader can be called in any order, including
/// some which do not correspond to any JSON structure.
/// Readers can be non-validating and accept any such incorrect
/// ordering of operations.
///
/// The returned reader will forward all methods to [reader],
/// but will ensure that methods are not called in an order
/// which does not correspond to a JSON structure.
JsonReader<T> validateJsonReader<T>(JsonReader<T> reader) =>
    ValidatingJsonReader<T>(reader);
