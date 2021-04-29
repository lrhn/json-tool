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

import "sink.dart";

/// A [JsonSink] which builds Dart object structures.
///
/// I only the plain [JsonSink] methods are used, in correct order,
/// then the structure will represent valid JSON and can be traversed
/// by the reader of [JsonReader.fromObject].
class JsonObjectWriter implements JsonSourceWriter<Object?> {
  /// The callback which is called for each complete JSON object.
  final void Function(dynamic) _result;

  /// Stack of objects or arrays being built, and pending [_key] values.
  final List<Object? > _stack = [];

  /// Last key added using [addKey].
  String? _key;

  JsonObjectWriter(this._result);

  void _value(Object? value) {
    if (_stack.isEmpty) {
      _result(value);
      _key = null;
    } else {
      var top = _stack.last;
      if (_key != null) {
        (top as Map<String?, dynamic>)[_key] = value;
        _key = null;
      } else {
        (top as List<dynamic>).add(value);
      }
    }
  }

  void addBool(bool value) {
    _value(value);
  }

  void endArray() {
    var array = _stack.removeLast();
    _key = _stack.removeLast() as String?;
    _value(array);
  }

  void endObject() {
    var object = _stack.removeLast();
    _key = _stack.removeLast() as String?;
    _value(object);
  }

  void addKey(String key) {
    _key = key;
  }

  void addNull() {
    _value(null);
  }

  void addNumber(num? value) {
    _value(value);
  }

  void startArray() {
    _stack.add(_key);
    _stack.add(<dynamic>[]);
    _key = null;
  }

  void startObject() {
    _stack.add(_key);
    _stack.add(<String, dynamic>{});
    _key = null;
  }

  void addString(String value) {
    _value(value);
  }

  void addSourceValue(Object? source) {
    _value(source);
  }
}
