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

import "sink.dart";

/// Validating [JsonSink] which checks that methods are only used correctly.
///
/// Maintains an internal state machine which knows whether the sink is
/// currently expecting a top-level value, an array value or an
/// object key or value.
final class ValidatingJsonSink implements JsonSink {
  /// The original sink. All method calls are forwarded to this after validation.
  final JsonSink _sink;

  final JsonStructureValidator _validator;

  ValidatingJsonSink(this._sink, bool allowReuse)
      : _validator = JsonStructureValidator(allowReuse: allowReuse);

  @override
  void addBool(bool value) {
    _validator.value();
    _sink.addBool(value);
  }

  @override
  void addKey(String key) {
    _validator.key();
    _sink.addKey(key);
  }

  @override
  void addNull() {
    _validator.value();
    _sink.addNull();
  }

  @override
  void addNumber(num value) {
    _validator.value();
    _sink.addNumber(value);
  }

  @override
  void addString(String value) {
    _validator.value();
    _sink.addString(value);
  }

  @override
  void endArray() {
    _validator.endArray();
    _sink.endArray();
  }

  @override
  void endObject() {
    _validator.endObject();
    _sink.endObject();
  }

  @override
  void startArray() {
    _validator.startArray();
    _sink.startArray();
  }

  @override
  void startObject() {
    _validator.startObject();
    _sink.startObject();
  }
}
