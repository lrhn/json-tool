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
final class JsonByteWriter implements JsonWriter<List<int>> {
  final Encoding _encoding;

  /// String characters with value above this are hex-encoded,
  /// below they are emitted as-is.
  final int _encodeLimit;
  final _NonClosingIntListSinkBase _target;
  StringConversionSink? _sink;
  String _separator = "";
  int _depth = 0;

  /// Creates a [JsonSink] which builds a byte representation of the JSON
  /// structure.
  ///
  /// The bytes are written to [sink], which is closed when a complete JSON
  /// value / object structure has been written.
  ///
  /// If [asciiOnly] is true, string values will escape any non-ASCII
  /// character.
  /// If false, which characters are converted is determined by the encoding.
  /// The recognized encodings are [ascii], [latin1] and [utf8].
  /// All other encodings will currently make all non-ASCII characters be
  /// encoded.
  ///
  /// The resulting byte representation is a minimal JSON text with no
  /// whitespace between tokens.
  JsonByteWriter(
    Sink<List<int>> target, {
    Encoding encoding = utf8,
    bool asciiOnly = false,
  })  : _encoding = encoding,
        _target = target is ByteConversionSink
            ? _NonClosingByteConversionSink(target)
            : _NonClosingIntListSink(target),
        _encodeLimit = _estimateEncodingLimit(asciiOnly, encoding);

  static int _estimateEncodingLimit(bool asciiOnly, Encoding encoding) {
    if (!asciiOnly) {
      if (identical(encoding, utf8)) return 0x10FFFF;
      if (identical(encoding, latin1)) return 0xFF;
    }
    return 0x7F;
  }

  /// Ensures that [_sink] contains an encoding sink wrapping [_target]].
  ///
  /// We wrap [_target] in wrapper which swallows close operations.
  /// This allows us to close the [_sink], which flushes any buffered
  /// data in the encoding sink.
  StringConversionSink _ensureSink() =>
      _sink ??= _encoding.encoder.startChunkedStringConversion(_target);

  void _closeAtEnd() {
    if (_depth == 0) {
      _sink?.close();
      // Because `_sink` is encoding to a `_NonClosingSink`, also close
      // `_target` manually.
      _target._close();
    }
  }

  @override
  void addBool(bool value) {
    var sink = _ensureSink();
    sink.add(_separator);
    if (value) {
      sink.add("true");
    } else {
      sink.add("false");
    }
    _separator = ",";
    _closeAtEnd();
  }

  @override
  void endArray() {
    _ensureSink().add("]");
    _separator = ",";
    _depth--;
    _closeAtEnd();
  }

  @override
  void endObject() {
    _ensureSink().add("}");
    _separator = ",";
    _depth--;
    _closeAtEnd();
  }

  @override
  void addKey(String key) {
    var sink = _ensureSink();
    sink.add(_separator);
    _writeString(sink, key, _encodeLimit);
    _separator = ":";
  }

  @override
  void addNull() {
    _ensureSink()
      ..add(_separator)
      ..add("null");
    _separator = ",";
    _closeAtEnd();
  }

  @override
  void addNumber(num value) {
    _ensureSink()
      ..add(_separator)
      ..add(value.toString());
    _separator = ",";
    _closeAtEnd();
  }

  @override
  void startArray() {
    _ensureSink()
      ..add(_separator)
      ..add("[");
    _separator = "";
    _depth++;
  }

  @override
  void startObject() {
    _ensureSink()
      ..add(_separator)
      ..add("{");
    _separator = "";
    _depth++;
  }

  @override
  void addString(String value) {
    var sink = _ensureSink();
    sink.add(_separator);
    _writeString(sink, value, _encodeLimit);
    _separator = ",";
    _closeAtEnd();
  }

  @override
  void addSourceValue(List<int> source) {
    // The `_target` sink is wrapped in `_NonClosingSink` in the constructor,
    // and here, because we close the `_sink` as a way to flush previous
    // encoding content before adding these bytes.
    // Then following [add]s will allocate a new encoding sink when necessary.
    var sink = _sink;
    if (sink != null) {
      // Write to and flush current encoding.
      sink
        ..add(_separator)
        ..close();
      _sink = null;
    } else if (_separator.isNotEmpty) {
      // No current encoding sink, so nothing to flush.
      // Just encode the separator manually, and add it to the target sink.
      _target.add(_encoding.encode(_separator));
    }
    _target.add(source);
    _separator = ",";
    _closeAtEnd();
  }
}

/// Writes [string] as a JSON string value to [sink].
///
/// String characters above [encodeLimit] are written as `\u....` escapes.
/// The [encodeLimit] is on of 0x7F (ASCII only), 0xFF (Latin-1) and
/// 0x10FFFF (UTF-8).
/// This ensures that the emitted characters are valid for the encoding.
/// (Unrecognized encodings emit only ASCII.)
void _writeString(StringConversionSink sink, String string, int encodeLimit) {
  if (string.isEmpty) {
    sink.add('""');
    return;
  }
  sink.add('"');
  var start = 0;
  for (var i = 0; i < string.length; i++) {
    var char = string.codeUnitAt(i);
    // 0x22 is `"`, 0x5c is `\`.
    if (char < 0x20 || char == 0x22 || char == 0x5c || char > encodeLimit) {
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
          sink.add(char < 0x100
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

abstract class _NonClosingIntListSinkBase extends ByteConversionSink {
  abstract final Sink<List<int>> _sink;

  @override
  void add(List<int> data) => _sink.add(data);

  @override
  void close() {
    // do nothing
  }

  // Actually close.
  void _close() {
    _sink.close();
  }
}

/// Wrap a [Sink] such that [close] will not close the underlying sink.
class _NonClosingIntListSink extends _NonClosingIntListSinkBase {
  @override
  final Sink<List<int>> _sink;

  _NonClosingIntListSink(this._sink);
}

class _NonClosingByteConversionSink extends _NonClosingIntListSinkBase {
  @override
  final ByteConversionSink _sink;

  _NonClosingByteConversionSink(this._sink);

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    _sink.addSlice(chunk, start, end, false);
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
