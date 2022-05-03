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

import "../reader/reader.dart";

/// A function reading JSON data from a [JsonReader] into a Dart value.
///
/// This is a general type which can be implemented
/// for any type that can be built from JSON data.
typedef JsonBuilder<T> = T Function(JsonReader);

/// Parses a JSON value from [reader] into a plain JSON-like structure.
///
/// A JSON-like structure is either a number, a string, a boolean, `null`, or
/// a `List<Object>` containing JSON-like structures, or a `Map<String, Object>`
/// where the values are JSON-like structures.
Object? jsonValue(JsonReader reader) {
  if (reader.checkObject()) {
    return jsonObject<Object?>(jsonValue)(reader);
  }
  if (reader.checkArray()) {
    return jsonArray<Object?>(jsonValue)(reader);
  }
  if (reader.tryNull()) return null;
  return reader.tryNum() ??
      reader.tryString() ??
      reader.tryBool() ??
      (throw FormatException("Reader has no value"));
}

/// Reads an integer from [reader].
int jsonInt(JsonReader reader) => reader.expectInt();

/// Reads a double from [reader].
double jsonDouble(JsonReader reader) => reader.expectDouble();

/// Reads a number from [reader].
num jsonNum(JsonReader reader) => reader.expectNum();

/// Reads a string from [reader].
String jsonString(JsonReader reader) => reader.expectString();

/// Reads a boolean from [reader].
bool jsonBool(JsonReader reader) => reader.expectBool();

/// Reads eiher a `null` or what [builder] reads from a [JsonReader].
///
/// If the next value of [builder] is `null`, then the result
/// is `null`, otherwise returns the same value as [builder]
/// on `reader`.
///
/// Can be used as, for example:
/// ```dart
/// var optionalJsonInt = jsonOptional(jsonInt);
/// var optionalInt = optionalJsonInt(reader);  // int or null
/// ```
JsonBuilder<T?> jsonOptional<T>(JsonBuilder<T> builder) =>
    (JsonReader reader) => reader.tryNull() ? null : builder(reader);

/// Reads an array of values from a [JsonReader].
///
/// Reads an array from the provided `reader`, where each
/// element of the array is built by [elementBuilder].
JsonBuilder<List<T>> jsonArray<T>(JsonBuilder<T> elementBuilder) =>
    (JsonReader reader) {
      reader.expectArray();
      var result = <T>[];
      while (reader.hasNext()) {
        result.add(elementBuilder(reader));
      }
      return result;
    };

/// Reads an array of values from [JsonReader].
///
/// The builder used for each element is provided
/// by the [elementBuilder] function based on the
/// index of the element. This allows, for example,
/// building an array that alternates between two
/// types.
JsonBuilder<List<T>> jsonIndexedArray<T>(
        JsonBuilder<T> Function(int index) elementBuilder) =>
    (JsonReader reader) {
      reader.expectArray();
      var result = <T>[];
      var index = 0;
      while (reader.hasNext()) {
        result.add(elementBuilder(index)(reader));
        index++;
      }
      return result;
    };

/// Builds a value from a JSON array.
///
/// Builds a value for each element using [elementBuilder],
/// then folds those into a single value using [initialValue]
/// and [combine], just like [Iterable.fold].
JsonBuilder<T> jsonFoldArray<T, E>(
        JsonBuilder<E> elementBuilder,
        T Function() initialValue,
        T Function(T previus, E elementValue) combine) =>
    (JsonReader reader) {
      reader.expectArray();
      var result = initialValue();
      while (reader.hasNext()) {
        var element = elementBuilder(reader);
        result = combine(result, element);
      }
      return result;
    };

/// Builds a map from a JSON object.
///
/// Reads a JSON object and builds a value for each object value
/// using [valueBuilder]. Then creates a `Map<String, T>` of
/// the keys and built values.
JsonBuilder<Map<String?, T>> jsonObject<T>(JsonBuilder<T> valueBuilder) =>
    (JsonReader reader) {
      reader.expectObject();
      var result = <String?, T>{};
      String? key;
      while ((key = reader.nextKey()) != null) {
        result[key] = valueBuilder(reader);
      }
      return result;
    };

/// Builds a map from a JSON object
///
/// Reads a JSON object and builds a value for each object value
/// using the builder returned by `valueBuilders[key]` for the corresponding
/// object key.
/// Then creates a `Map<String, T>` of the keys and built values.
///
/// The [defaultBuilder] is used if [valueBuilders] has no entry for
/// a give key. If there is no [defaultBuilder] and not entry in
/// [valueBuilders] for a key, then the entry is ignored.
JsonBuilder<Map<String?, T>> jsonStruct<T>(
        Map<String, JsonBuilder<T>> valueBuilders,
        [JsonBuilder<T>? defaultBuilder]) =>
    (JsonReader reader) {
      reader.expectObject();
      var result = <String?, T>{};
      var key = reader.nextKey();
      while (key != null) {
        var builder = valueBuilders[key] ?? defaultBuilder;
        if (builder != null) {
          result[key] = builder(reader);
        } else {
          reader.skipAnyValue();
        }
        key = reader.nextKey();
      }
      return result;
    };

/// Reads a JSON object and combines its entries into a single value.
///
/// Each entry value is built using [elementBuilder],
/// then the keys and those values are combined using [combine].
///
/// Equivalent to
/// ```dart
///  jsonObject(elementBuilder).entries.fold(initialValue(), (value, entry) =>
///      combine(value, entry.key, entry.value));
/// ```
JsonBuilder<T> jsonFoldObject<T, E>(
        JsonBuilder<E> elementBuilder,
        T Function() initialValue,
        T Function(T previus, String? key, E elementValue) combine) =>
    (JsonReader reader) {
      reader.expectObject();
      var result = initialValue();
      String? key;
      while ((key = reader.nextKey()) != null) {
        var element = elementBuilder(reader);
        result = combine(result, key, element);
      }
      return result;
    };

/// Builds a [DateTime] from a JSON string read from [reader].
DateTime jsonDateString(JsonReader reader) =>
    DateTime.parse(reader.expectString());

/// Builds a [Uri] from a JSON string read from [reader].
Uri jsonUriString(JsonReader reader) => Uri.parse(reader.expectString());
