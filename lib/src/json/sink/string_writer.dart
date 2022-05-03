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

/// A [JsonSink] which builds a textual representation of the JSON structure.
///
/// The resulting string representation is a minimal JSON text with no
/// whitespace between tokens.
class JsonStringWriter implements JsonWriter<String> {
  final StringSink _sink;
  final bool _asciiOnly;
  String _separator = "";

  /// Creates a writer which writes the result into [target].
  ///
  /// When an entire JSON value has been written, [target]
  /// will contain the string representation.
  ///
  /// If [asciiOnly] is true, string values will escape any non-ASCII
  /// character. If not, only control characters are escaped.
  JsonStringWriter(StringSink target, {bool asciiOnly = false})
      : _sink = target,
        _asciiOnly = asciiOnly;

  @override
  void addBool(bool value) {
    _sink.write(_separator);
    _sink.write(value);
    _separator = ",";
  }

  @override
  void endArray() {
    _sink.write("]");
    _separator = ",";
  }

  @override
  void endObject() {
    _sink.write("}");
    _separator = ",";
  }

  @override
  void addKey(String key) {
    _sink.write(_separator);
    _writeString(_sink, key, _asciiOnly);
    _separator = ":";
  }

  @override
  void addNull() {
    _sink.write(_separator);
    _sink.write("null");
    _separator = ",";
  }

  @override
  void addNumber(num? value) {
    _sink.write(_separator);
    _sink.write(value);
    _separator = ",";
  }

  @override
  void startArray() {
    _sink.write(_separator);
    _sink.write("[");
    _separator = "";
  }

  @override
  void startObject() {
    _sink.write(_separator);
    _sink.write("{");
    _separator = "";
  }

  @override
  void addString(String value) {
    _sink.write(_separator);
    _writeString(_sink, value, _asciiOnly);
    _separator = ",";
  }

  @override
  void addSourceValue(String source) {
    _sink.write(_separator);
    _sink.write(source);
    _separator = ",";
  }
}

/// A [JsonSink] which builds a pretty textual representation of the JSON.
///
/// The textual representation is spread on multiple lines and
/// the content of JSON arrays or objects are indented.
class JsonPrettyStringWriter implements JsonWriter<String> {
  final StringSink _sink;
  final bool _asciiOnly;
  final String _indentString;
  int _indent = 0;
  String? _separator = "";

  /// Creates a writer which writes the result into [target].
  ///
  /// The [indentString] is used for indenting nested structures
  /// on new lines. If [indentString] is not pure whitespace,
  /// typically a single TAB character or a number of space characters,
  /// then the resulting text may not be valid JSON.
  ///
  /// If [asciiOnly] is true, string values will escape any non-ASCII
  /// character. If not, only control characters are escaped.
  JsonPrettyStringWriter(StringSink target, String indentString,
      {bool asciiOnly = false})
      : _sink = target,
        _indentString = indentString,
        _asciiOnly = asciiOnly;

  void _writeSeparator() {
    if (_separator != null) {
      _sink.write(_separator);
      _writeIndent();
    }
  }

  void _writeIndent() {
    _sink.write("\n");
    for (var i = 0; i < _indent; i++) {
      _sink.write(_indentString);
    }
  }

  @override
  void addBool(bool value) {
    _writeSeparator();
    _sink.write(value);
    _separator = ",";
  }

  @override
  void endArray() {
    _indent--;
    _writeIndent();
    _sink.write("]");
    _separator = ",";
  }

  @override
  void endObject() {
    _indent--;
    _writeIndent();
    _sink.write("}");
    _separator = ",";
  }

  @override
  void addKey(String key) {
    _writeSeparator();
    _writeString(_sink, key, _asciiOnly);
    _sink.write(": ");
    _separator = null;
  }

  @override
  void addNull() {
    _writeSeparator();
    _sink.write("null");
    _separator = ",";
  }

  @override
  void addNumber(num? value) {
    _writeSeparator();
    _sink.write(value);
    _separator = ",";
  }

  @override
  void startArray() {
    _writeSeparator();
    _sink.write("[");
    _indent++;
    _separator = "";
  }

  @override
  void startObject() {
    _writeSeparator();
    _sink.write("{");
    _indent++;
    _separator = "";
  }

  @override
  void addString(String value) {
    _writeSeparator();
    _writeString(_sink, value, _asciiOnly);
    _separator = ",";
  }

  @override
  void addSourceValue(String source) {
    _writeSeparator();
    _sink.write(source);
    _separator = ",";
  }
}

void _writeString(StringSink sink, String string, bool asciiOnly) {
  sink.write('"');
  var start = 0;
  for (var i = 0; i < string.length; i++) {
    var char = string.codeUnitAt(i);
    if (char < 0x20 ||
        char == 0x22 ||
        char == 0x5c ||
        (asciiOnly && char > 0x7f)) {
      if (i > start) sink.write(string.substring(start, i));
      switch (char) {
        case 0x08:
          sink.write(r"\b");
          break;
        case 0x09:
          sink.write(r"\t");
          break;
        case 0x0a:
          sink.write(r"\n");
          break;
        case 0x0c:
          sink.write(r"\f");
          break;
        case 0x0d:
          sink.write(r"\r");
          break;
        case 0x22:
          sink.write(r'\"');
          break;
        case 0x5c:
          sink.write(r"\\");
          break;
        default:
          sink.write(char < 256
              ? (char < 0x10 ? r"\u000" : r"\u00")
              : (char < 0x1000 ? r"\u0" : r"\u"));
          sink.write(char.toRadixString(16));
      }
      start = i + 1;
    }
  }
  if (start < string.length) sink.write(string.substring(start));
  sink.write('"');
}
