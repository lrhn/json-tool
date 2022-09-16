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
class JsonObjectWriter implements JsonWriter<Object?> {
  /// The callback which is called for each complete JSON object.
  final void Function(Object?) _result;

  /// Stack of objects or arrays being built, and pending [_key] values.
  final List<Object?> _stack = [];

  /// Last key added using [addKey].
  String? _key;

  // Typed caches of the top of the [_stack].
  // Set when pushing a new map or list on the stack.
  // Filled in lazily when first needed after popping the stack,
  Map? _topObjectCache;
  List? _topArrayCache;

  JsonObjectWriter(this._result);

  void _value(Object? value) {
    if (_stack.isEmpty) {
      _result(value);
      _key = null;
    } else {
      var key = _key;
      if (key != null) {
        Map topObject = _topObjectCache ??= (_stack.last as dynamic);
        topObject[key] = value;
        _key = null;
      } else {
        List topArray = _topArrayCache ??= (_stack.last as dynamic);
        topArray.add(value);
      }
    }
  }

  @override
  void addBool(bool value) {
    _value(value);
  }

  @override
  void endArray() {
    var top = _stack.removeLast();
    List array = _topArrayCache ?? (top as dynamic);
    _key = _stack.removeLast() as dynamic;
    _topArrayCache = null;
    _value(array);
  }

  @override
  void endObject() {
    var top = _stack.removeLast();
    Map object = _topObjectCache ?? (top as dynamic);
    _key = _stack.removeLast() as dynamic;
    _topObjectCache = null;
    _value(object);
  }

  @override
  void addKey(String key) {
    _key = key;
  }

  @override
  void addNull() {
    _value(null);
  }

  @override
  void addNumber(num? value) {
    _value(value);
  }

  @override
  void startArray() {
    var array = <dynamic>[];
    _stack.add(_key);
    _stack.add(array);
    _topArrayCache = array;
    _topObjectCache = null;
    _key = null;
  }

  @override
  void startObject() {
    var object = <String, dynamic>{};
    _stack.add(_key);
    _stack.add(object);
    _topArrayCache = null;
    _topObjectCache = object;
    _key = null;
  }

  @override
  void addString(String value) {
    _value(value);
  }

  @override
  void addSourceValue(Object? source) {
    _value(source);
  }
}
