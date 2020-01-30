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

import "package:jsontool/jsontool.dart";

/// A progressive JSON structure sink validator.
///
/// Maintains a state representing a prefix of a valid JSON structure,
/// with ways to query that state, and it allows only valid continuations
/// to be added to the state.
///
/// A valid JSON structure represents a single JSON value, either
/// a primitive value or a compositve value.
///
/// It must satisfy:
/// * A [startArray] must be followed by a, potentially empty, sequence of
///  valid JSON structures, and then an [endArray].
/// * A [startObject] must be followed by a, potentially empty, sequence of
///   [addKey] and values pairs where the values are valid JSON structures,
///   an then an [endObject].
///
/// The state will eventually represent a single JSON value, or
/// a sequence of JSON values if the validator is *reusable*.
///
/// The current state can be queried using
/// [allowsValue], [allowsKey], [isArray], [isObject] and [hasValue].
class JsonStructureValidator {
  // Whether a composite structure contains any values yet.
  static const int _hasValue = 1;
  // If set in state, removes _allowValue from the state when a value is provided.
  static const int _preventValueAfter = 2;
  // Whether a state allows a value.
  static const int _allowValue = 4;
  // Being inside a composite value.
  static const int _insideComposite = 8;

  /// State expecting a single top-level value.
  static const int _stateInitial = _allowValue | _preventValueAfter;

  /// State expecting multiple top-level values.
  static const int _stateInitialReusable = _allowValue;

  /// State expecting a value in an array, or ending the array.
  static const int _stateArray = _insideComposite | _allowValue;

  /// State expecting an object key or ending the object..
  static const int _stateObjectKey = _insideComposite | _preventValueAfter;

  /// State expecting an object value, after seeing a key.
  static const int _stateObjectValue =
      _insideComposite | _allowValue | _preventValueAfter;

  /// Stack of states to return to when ending an array or object.
  final List<int> _stateStack = [];

  /// Current state.
  int _state;

  /// Creates a validating [JsonSink].
  ///
  /// Events sent to the sink must describe a valid JSON structure.
  JsonStructureValidator({bool allowReuse = false})
      : _state = allowReuse ? _stateInitialReusable : _stateInitial;

  /// Add a JSON value.
  ///
  /// Throws if a value cannot occur at the current position.
  ///
  /// Since this sink does not care which value is being added,
  /// this method can be used to represent any primitive value,
  /// or even a composite value that needs not be checked.
  void value() {
    _value();
  }

  void _value() {
    if (!allowsValue) {
      throw StateError("Cannot add value");
    }
    _state = _state ^ ((_state & _preventValueAfter) * 2) | _hasValue;
  }

  /// Adds an object key.
  ///
  /// Throws if an object key cannot occur at the current position.
  void key() {
    if (!allowsKey) {
      throw StateError("Cannot add key");
    }
    _state = _stateObjectValue;
  }

  /// Ends an array.
  ///
  /// Throws if not inside an array.
  void endArray() {
    if (!isArray) {
      throw StateError("Not inside array");
    }
    _state = _stateStack.removeLast();
  }

  /// Ends an object.
  ///
  /// Throws if not inside an object, or if positioned after an object key
  /// which has not received a value.
  void endObject() {
    if (!allowsKey) {
      throw StateError("Not at object end");
    }
    _state = _stateStack.removeLast();
  }

  /// Starts an array.
  ///
  /// Throws if a value cannot occur at the current position.
  ///
  /// When the array is closed, the value is considered added
  /// to the surrounding context.
  void startArray() {
    _value();
    _stateStack.add(_state);
    _state = _stateArray;
  }

  /// Starts an object.
  ///
  /// Throws if a value cannot occur at the current position.
  ///
  /// When the object is closed, the value is considered added
  /// to the surrounding context.
  void startObject() {
    _value();
    _stateStack.add(_state);
    _state = _stateObjectKey;
  }

  /// Checks whether a value is currently allowed.
  ///
  /// Throws if it is not, but does not change the state to assume that
  /// a value has actually been added.
  bool get allowsValue => _state & _allowValue != 0;

  /// Checks whether an object key is currently allowed.
  ///
  /// This is only true if inside an object ([isObject]) and
  /// not allowing a value.
  ///
  /// Throws if it is not, but does not change the state to assume that
  /// a key has actually been added.
  bool get allowsKey =>
      (_state & (_insideComposite | _allowValue)) == _insideComposite;

  /// Whether the current position is immediately inside an array.
  bool get isArray =>
      _state & (_insideComposite | _preventValueAfter) == _insideComposite;

  /// Whether the current position is immediately inside an object.
  bool get isObject =>
      _state & (_insideComposite | _preventValueAfter) ==
      (_insideComposite | _preventValueAfter);

  /// Whether the current position is inside any array.
  bool get insideArray {
    var state = _state;
    var i = _stateStack.length - 1;
    while (true) {
      if (state & (_insideComposite | _preventValueAfter) == _insideComposite) {
        return true;
      }
      if (i <= 0) return false;
      state = _stateStack[i];
      i--;
    }
  }

  /// Whether the current position is inside any object.
  bool get insideObject {
    var state = _state;
    var i = _stateStack.length - 1;
    while (true) {
      if (state & (_insideComposite | _preventValueAfter) ==
          (_insideComposite | _preventValueAfter)) {
        return true;
      }
      if (i <= 0) return false;
      state = _stateStack[i];
      i--;
    }
  }

  /// Whether a value has been read.
  ///
  /// If [isArray] then whether a value has been added to that array.
  /// If [isObjet] then whether a key/value pair has been added to the object.
  /// If neither, then whether a value has been added.
  bool get hasValue => _state & _hasValue != 0;
}
