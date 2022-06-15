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

import "../json_structure_validator.dart";
import "../sink/sink.dart";
import "reader.dart";
import "util.dart";

/// A validating JSON reader which checks the member invocation sequence.
///
/// The members must only be used in situations where the operation is.
class ValidatingJsonReader<SourceSlice> implements JsonReader<SourceSlice> {
  final JsonStructureValidator _validator = JsonStructureValidator();
  final JsonReader<SourceSlice> _reader;
  // If in an array, whether `hasNext` has been called.
  bool _needsHasNext = false;

  ValidatingJsonReader(this._reader);

  void _checkValueAllowed() {
    if (_needsHasNext || !_validator.allowsValue) {
      throw StateError("Value not allowed: $_needsHasNext");
    }
  }

  void _checkKeyAllowed() {
    if (!_validator.allowsKey) {
      throw StateError("Key not allowed");
    }
  }

  @override
  bool checkArray() {
    _checkValueAllowed();
    return _reader.checkArray();
  }

  @override
  bool checkBool() {
    _checkValueAllowed();
    return _reader.checkBool();
  }

  @override
  bool checkNull() {
    _checkValueAllowed();
    return _reader.checkNull();
  }

  @override
  bool checkNum() {
    _checkValueAllowed();
    return _reader.checkNum();
  }

  @override
  bool checkObject() {
    _checkValueAllowed();
    return _reader.checkObject();
  }

  @override
  bool checkString() {
    _checkValueAllowed();
    return _reader.checkString();
  }

  @override
  JsonReader copy() {
    return _reader.copy();
  }

  @override
  void expectAnyValue(JsonSink sink) {
    _checkValueAllowed();
    _reader.expectAnyValue(sink);
    _validator.value();
    _needsHasNext = _validator.isArray;
  }

  @override
  SourceSlice expectAnyValueSource() {
    _checkValueAllowed();
    var result = _reader.expectAnyValueSource();
    _validator.value();
    _needsHasNext = _validator.isArray;
    return result;
  }

  @override
  void expectArray() {
    _checkValueAllowed();
    _reader.expectArray();
    _validator.startArray();
    _needsHasNext = true;
  }

  @override
  bool expectBool() {
    _checkValueAllowed();
    var result = _reader.expectBool();
    _validator.value();
    _needsHasNext = _validator.isArray;
    return result;
  }

  @override
  double expectDouble() {
    _checkValueAllowed();
    var result = _reader.expectDouble();
    _validator.value();
    _needsHasNext = _validator.isArray;
    return result;
  }

  @override
  int expectInt() {
    _checkValueAllowed();
    var result = _reader.expectInt();
    _validator.value();
    _needsHasNext = _validator.isArray;
    return result;
  }

  @override
  void expectNull() {
    _checkValueAllowed();
    _reader.expectNull();
    _validator.value();
    _needsHasNext = _validator.isArray;
  }

  @override
  num expectNum() {
    _checkValueAllowed();
    var result = _reader.expectNum();
    _validator.value();
    _needsHasNext = _validator.isArray;
    return result;
  }

  @override
  void expectObject() {
    _checkValueAllowed();
    _reader.expectObject();
    _validator.startObject();
  }

  @override
  String expectString([List<String>? candidates]) {
    _checkValueAllowed();
    var result = _reader.expectString(candidates);
    _validator.value();
    _needsHasNext = _validator.isArray;
    return result;
  }

  @override
  bool hasNext() {
    if (!_needsHasNext) {
      throw StateError("Cannot use hasNext");
    }
    _needsHasNext = false;
    if (_reader.hasNext()) {
      return true;
    }
    _validator.endArray();
    return false;
  }

  @override
  String? nextKey() {
    if (!_validator.allowsKey) {
      throw StateError("Does not allow key");
    }
    var result = _reader.nextKey();
    if (result == null) {
      _validator.endObject();
      _needsHasNext = _validator.isArray;
    } else {
      _validator.key();
    }
    return result;
  }

  @override
  bool hasNextKey() {
    if (!_validator.allowsKey) {
      throw StateError("Does not allow key");
    }
    var result = _reader.hasNextKey();
    if (!result) {
      _validator.endObject();
      _needsHasNext = _validator.isArray;
    }
    return result;
  }

  @override
  SourceSlice? nextKeySource() {
    if (!_validator.allowsKey) {
      throw StateError("Does not allow key");
    }
    var result = _reader.nextKeySource();
    if (result == null) {
      _validator.endObject();
    } else {
      _validator.key();
    }
    _needsHasNext = _validator.isArray;
    return result;
  }

  @override
  void skipAnyValue() {
    _validator.value();
    _reader.skipAnyValue();
    _needsHasNext = _validator.isArray;
  }

  @override
  void endArray() {
    if (!_validator.insideArray) {
      throw StateError("Not in array");
    }
    _reader.endArray();
    while (_validator.isObject) {
      if (_validator.allowsValue) {
        _validator.value();
      }
      _validator.endObject();
    }
    assert(_validator.isArray);
    _validator.endArray();
    _needsHasNext = _validator.isArray;
  }

  @override
  void endObject() {
    if (!_validator.insideObject) {
      throw StateError("Not in object");
    }
    _reader.endObject();
    while (_validator.isArray) {
      _validator.endArray();
    }
    assert(_validator.isObject);
    if (_validator.allowsValue) {
      // After key.
      _validator.value();
    }
    _validator.endObject();
    _needsHasNext = _validator.isArray;
  }

  @override
  bool skipObjectEntry() {
    _checkKeyAllowed();
    if (!_reader.skipObjectEntry()) {
      _validator.endObject();
      return false;
    }
    return true;
  }

  @override
  bool tryArray() {
    _checkValueAllowed();
    if (_reader.tryArray()) {
      _validator.startArray();
      _needsHasNext = true;
      return true;
    }
    return false;
  }

  @override
  bool? tryBool() {
    _checkValueAllowed();
    var result = _reader.tryBool();
    if (result != null) {
      _validator.value();
      _needsHasNext = _validator.isArray;
    }
    return result;
  }

  @override
  double? tryDouble() {
    _checkValueAllowed();
    var result = _reader.tryDouble();
    if (result != null) {
      _validator.value();
      _needsHasNext = _validator.isArray;
    }
    return result;
  }

  @override
  int? tryInt() {
    _checkValueAllowed();
    var result = _reader.tryInt();
    if (result != null) {
      _validator.value();
      _needsHasNext = _validator.isArray;
    }
    return result;
  }

  @override
  String? tryKey(List<String> candidates) {
    if (!areSorted(candidates)) {
      throw ArgumentError("Candidates are not sorted");
    }
    _checkKeyAllowed();
    var result = _reader.tryKey(candidates);
    if (result != null) {
      _validator.key();
      _needsHasNext = _validator.isArray;
    }
    return result;
  }

  @override
  bool tryNull() {
    _checkValueAllowed();
    if (_reader.tryNull()) {
      _validator.value();
      _needsHasNext = _validator.isArray;
      return true;
    }
    return false;
  }

  @override
  num? tryNum() {
    _checkValueAllowed();
    var result = _reader.tryNum();
    if (result != null) {
      _validator.value();
      _needsHasNext = _validator.isArray;
    }
    return result;
  }

  @override
  bool tryObject() {
    _checkValueAllowed();
    var result = _reader.tryObject();
    if (result) {
      _validator.startObject();
    }
    return result;
  }

  @override
  String? tryString([List<String>? candidates]) {
    _checkValueAllowed();
    var result = _reader.tryString(candidates);
    if (result != null) {
      _validator.value();
      _needsHasNext = _validator.isArray;
    }
    return result;
  }
}
