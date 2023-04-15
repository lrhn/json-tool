// Copyright 2022 Google LLC
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

import "sink.dart";

/// A [JsonSink] which builds a binary representation of the JSON
/// structure.
///
/// The resulting string representation is a minimal JSON text with no
/// whitespace between tokens.
class JsonByteWriter implements JsonWriter<List<int>> {
  final Encoding _encoding;
  final bool _asciiOnly;
  final Sink<List<int>> _target;
  StringConversionSink _sink;
  String _separator = "";
  int _depth = 0;

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
  JsonByteWriter(
    Sink<List<int>> target, {
    Encoding encoding = utf8,
    bool? asciiOnly,
  })  : _encoding = encoding,
        _target = target,
        _sink = encoding.encoder
            .startChunkedStringConversion(_NonClosingSink(target)),
        _asciiOnly = asciiOnly ?? encoding != utf8;

  void _closeAtEnd() {
    if (_depth == 0) {
      _sink.close();
      _target.close();
    }
  }

  @override
  void addBool(bool value) {
    _sink.add(_separator);
    if (value) {
      _sink.add("true");
    } else {
      _sink.add("false");
    }
    _separator = ",";
    _closeAtEnd();
  }

  @override
  void endArray() {
    _sink.add("]");
    _separator = ",";
    _depth--;
    _closeAtEnd();
  }

  @override
  void endObject() {
    _sink.add("}");
    _separator = ",";
    _depth--;
    _closeAtEnd();
  }

  @override
  void addKey(String key) {
    _sink.add(_separator);
    _writeString(_sink, key, _asciiOnly);
    _separator = ":";
  }

  @override
  void addNull() {
    _sink.add(_separator);
    _sink.add("null");
    _separator = ",";
    _closeAtEnd();
  }

  @override
  void addNumber(num? value) {
    _sink.add(_separator);
    _sink.add(value.toString());
    _separator = ",";
    _closeAtEnd();
  }

  @override
  void startArray() {
    _sink.add(_separator);
    _sink.add("[");
    _separator = "";
    _depth++;
  }

  @override
  void startObject() {
    _sink.add(_separator);
    _sink.add("{");
    _separator = "";
    _depth++;
  }

  @override
  void addString(String value) {
    _sink.add(_separator);
    _writeString(_sink, value, _asciiOnly);
    _separator = ",";
    _closeAtEnd();
  }

  @override
  void addSourceValue(List<int> source) {
    _sink.add(_separator);
    _sink.close();
    _target.add(source);
    _sink = _encoding.encoder
        .startChunkedStringConversion(_NonClosingSink(_target));
    _separator = ",";
    _closeAtEnd();
  }
}

void _writeString(StringConversionSink sink, String string, bool asciiOnly) {
  sink.add('"');
  var start = 0;
  for (var i = 0; i < string.length; i++) {
    var char = string.codeUnitAt(i);
    if (char < 0x20 ||
        char == 0x22 ||
        char == 0x5c ||
        (asciiOnly && char > 0x7f)) {
      if (i > start) sink.addSlice(string, start, i, false);
      switch (char) {
        case 0x08:
          sink.add(r"\b");
          break;
        case 0x09:
          sink.add(r"\t");
          break;
        case 0x0a:
          sink.add(r"\n");
          break;
        case 0x0c:
          sink.add(r"\f");
          break;
        case 0x0d:
          sink.add(r"\r");
          break;
        case 0x22:
          sink.add(r'\"');
          break;
        case 0x5c:
          sink.add(r"\\");
          break;
        default:
          sink.add(char < 256
              ? (char < 0x10 ? r"\u000" : r"\u00")
              : (char < 0x1000 ? r"\u0" : r"\u"));
          sink.add(char.toRadixString(16));
      }
      start = i + 1;
    }
  }
  if (start < string.length) sink.addSlice(string, start, string.length, false);
  sink.add('"');
}

/// Wrap a [Sink] such that [close] will not close the underlying sink.
class _NonClosingSink<T> implements Sink<T> {
  final Sink<T> _sink;

  _NonClosingSink(this._sink);

  @override
  void add(T data) => _sink.add(data);

  @override
  void close() {
    // do nothing
  }
}

extension on Converter<String, List<int>> {
  /// Starts a chunked conversion.
  ///
  /// This calls [startChunkedConversion] and wraps in a [StringConversionSink]
  /// if necessary. Most implementations of [Encoding.encoder] has a
  /// specialization that returns [StringConversionSink].
  StringConversionSink startChunkedStringConversion(Sink<List<int>> sink) {
    final stringSink = startChunkedConversion(sink);
    if (stringSink is StringConversionSink) {
      return stringSink;
    }
    return StringConversionSink.from(stringSink);
  }
}
