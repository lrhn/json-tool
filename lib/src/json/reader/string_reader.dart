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

import "../sink/sink.dart";
import "reader.dart";
import "util.dart";
import 'util.dart';
import 'util.dart';
import 'util.dart';

/// A non-validating string-based [JsonReader].
class JsonStringReader implements JsonReader<StringSlice> {
  /// The source string being read.
  final String _source;

  /// The current position in the _source string.
  int _index;

  /// Creates scanner for JSON [source].
  JsonStringReader(String source) : this._(source, 0);

  /// Used by [copy] to create a copy of this reader's state.
  JsonStringReader._(this._source, this._index);

  FormatException _error(String message, [int /*?*/ index]) =>
      FormatException(message, _source, index ?? _index);

  void expectObject() {
    if (!tryObject()) throw _error("Not an object");
  }

  bool tryObject() {
    var char = _nextNonWhitespaceChar();
    if (char == $lbrace) {
      _index++;
      return true;
    }
    return false;
  }

  String /*?*/ nextKey() {
    var nextKey = _nextKeyStart();
    if (nextKey == $rbrace) {
      _index++;
      return null;
    }
    if (nextKey == $quot) {
      var key = _scanString();
      _expectColon();
      return key;
    }
    throw _error("Not a string");
  }

  StringSlice /*?*/ nextKeySource() {
    var nextKey = _nextKeyStart();
    if (nextKey == $rbrace) {
      _index++;
      return null;
    }
    if (nextKey == $quot) {
      var start = _index;
      _index++;
      if (!_skipString()) {
        throw _error("Unterminated string");
      }
      var end = _index;
      _expectColon();
      return StringSlice(_source, start, end);
    }
    throw _error("Not a string");
  }

  String /*?*/ tryKey(List<String> candidates) {
    assert(areSorted(candidates),
        throw ArgumentError.value(candidates, "candidates", "Are not sorted"));
    if (candidates.isEmpty) return null;
    var nextKey = _nextKeyStart();
    if (nextKey == $rbrace) return null;
    if (nextKey != $quot) throw _error("Not a string");
    var result = _tryCandidateString(candidates);
    if (result != null) {
      _expectColon();
    }
    return result;
  }

  /// Finds the start of the next key.
  ///
  /// Returns the code point for `"` if a string/key is found.
  /// Returns the code point for `}` if the end of object is found.
  /// Returns something else otherwise.
  int _nextKeyStart() {
    var char = _nextNonWhitespaceChar();
    if (char == $rbrace) {
      return char;
    }
    if (char == $comma) {
      assert(_prevNonWhitespaceChar() != $lbrace, throw _error("Not a value"));
      _index++;
      char = _nextNonWhitespaceChar();
    }
    return char;
  }

  void _expectColon() {
    var char = _nextNonWhitespaceChar();
    if (char != $colon) throw _error("Not a colon");
    _index++;
  }

  /// Checks for a string literal containing an element of candidates.
  ///
  /// Must be positioned at a `"` character.
  /// The candidates must be sorted ASCII strings.
  String /*?*/ _tryCandidateString(List<String> candidates) {
    var min = 0;
    var max = candidates.length;
    var start = _index + 1;
    var i = 0;
    while (start + i < _source.length) {
      var char = _source.codeUnitAt(start + i);
      if (char == $backslash) return null;
      if (char == $quot) break;
      String candidate;
      while ((candidate = candidates[min]).length <= i ||
          candidate.codeUnitAt(i) != char) {
        min++;
        if (min == max) return null;
      }
      var cursor = min + 1;
      while (cursor < max && candidates[cursor].codeUnitAt(i) == char) {
        cursor++;
      }
      max = cursor;
      i++;
    }
    var candidate = candidates[min];
    if (candidate.length == i) {
      _index = start + i + 1;
      return candidate;
    }
    return null;
  }

  bool skipObjectEntry() {
    var nextChar = _nextNonWhitespaceChar();
    var index = _index;
    if (nextChar == $quot) {
      _index++;
      _skipString();
      if (_nextNonWhitespaceChar() == $colon) {
        _index++;
        _skipValue();
        return true;
      }
    } else if (nextChar == $rbrace) {
      _index++;
      return false;
    }
    throw _error("Not an Object entry", index);
  }

  void endObject() {
    _skipUntil($rbrace);
  }

  void expectArray() {
    if (!tryArray()) throw _error("Not an array");
  }

  bool tryArray() {
    var char = _nextNonWhitespaceChar();
    if (char == $lbracket) {
      _index++;
      return true;
    }
    return false;
  }

  bool hasNext() {
    var char = _nextNonWhitespaceChar();
    if (char == $comma) {
      assert(
          _prevNonWhitespaceChar() != $lbracket, throw _error("Not a value"));
      _index++;
      return true;
    }
    if (char != $rbracket) {
      return true;
    }
    _index++;
    return false;
  }

  void endArray() {
    _skipUntil($rbracket);
  }

  /// Skips all values until seeing [endChar], which is always one of `]` and `}`.
  ///
  /// Returns true if successful and false if reaching end-of-input without
  /// finding the end.
  bool _skipUntil(int endChar) {
    while (_index < _source.length) {
      var char = _source.codeUnitAt(_index++);
      if (char == endChar) return true;
      if (char == $quot) {
        if (!_skipString()) return false;
      } else if (char == $lbrace) {
        if (!_skipUntil($rbrace)) return false;
      } else if (char == $lbracket) {
        if (!_skipUntil($rbracket)) return false;
      }
    }
    return false;
  }

  /// Skips to the end of a string.
  ///
  /// The start [_index] should be just after the leading quote
  /// character of a string literal.
  bool _skipString() {
    while (_index < _source.length) {
      var char = _source.codeUnitAt(_index++);
      if (char == $quot) return true;
      if (char == $backslash) _index++;
    }
    return false;
  }

  String expectString([List<String> candidates]) {
    assert(candidates == null || areSorted(candidates),
        throw ArgumentError.value(candidates, "candidates", "Are not sorted"));
    var char = _nextNonWhitespaceChar();
    if (char != $quot) {
      throw _error("Not a string");
    }
    if (candidates != null) {
      var result = _tryCandidateString(candidates);
      if (result == null) {
        throw _error("Not an expected string");
      }
      return result;
    }
    return _scanString();
  }

  String _scanString() {
    assert(_source.codeUnitAt(_index) == $quot);
    _index++;
    StringBuffer /*?*/ buffer;
    var start = _index;
    while (_index < _source.length) {
      var char = _source.codeUnitAt(_index++);
      if (char == $quot) {
        var slice = _source.substring(start, _index - 1);
        if (buffer == null) return slice;
        return (buffer..write(slice)).toString();
      }
      if (char == $backslash) {
        var buf = (buffer ??= StringBuffer());
        buf..write(_source.substring(start, _index - 1));
        if (_index < _source.length) {
          char = _source.codeUnitAt(_index++);
          start = _scanEscape(buf, char);
        } else {
          throw _error("Invalid escape");
        }
      }
    }
    throw _error("Unterminated string");
  }

  int _scanEscape(StringBuffer buffer, int escapeChar) {
    switch (escapeChar) {
      case $u:
        if (_index + 4 <= _source.length) {
          var value = 0;
          for (var i = 0; i < 4; i++) {
            var char = _source.codeUnitAt(_index + i);
            var digit = char ^ $0;
            if (digit <= 9) {
              value = value * 16 + digit;
            } else {
              char |= 0x20;
              if (char >= $a && char <= $f) {
                value = value * 16 + (char - ($a - 10));
              } else {
                throw _error("Invalid escape", _index - 1);
              }
            }
          }
          buffer.writeCharCode(value);
          _index += 4;
          break;
        }
        throw _error("Invalid escape", _index - 1);
      case $quot:
      case $slash:
      case $backslash:
        return _index - 1;
      case $t:
        buffer.write("\t");
        break;
      case $r:
        buffer.write("\r");
        break;
      case $n:
        buffer.write("\n");
        break;
      case $f:
        buffer.write("\f");
        break;
      case $b:
        buffer.write("\b");
        break;
      default:
        throw _error("Invalid escape", _index - 1);
    }
    return _index;
  }

  bool /*?*/ tryBool() {
    var char = _nextNonWhitespaceChar();
    if (char == $t) {
      assert(_source.startsWith("rue", _index + 1));
      _index += 4;
      return true;
    } else if (char == $f) {
      assert(_source.startsWith("alse", _index + 1));
      _index += 5;
      return false;
    }
    return null;
  }

  bool expectBool() => tryBool() ?? (throw _error("Not a boolean"));

  bool tryNull() {
    var char = _nextNonWhitespaceChar();
    if (char == $n) {
      assert(_source.startsWith("ull", _index + 1));
      _index += 4;
      return true;
    }
    return false;
  }

  void expectNull() {
    tryNull() || (throw _error("Not null"));
  }

  int expectInt() => _scanInt(true) /*!*/;

  int tryInt() => _scanInt(false);

  int /*?*/ _scanInt(bool throws) {
    var char = _nextNonWhitespaceChar();
    _index++;
    var sign = 1;
    if (char == $minus || char == $plus) {
      // $minus is 0x2d, $plus is $2b
      sign = 0x2c - char;
      if (_index < _source.length) {
        char = _source.codeUnitAt(_index++);
      } else {
        _index--;
        if (!throws) return null;
        throw _error("Not an integer");
      }
    }
    var result = char ^ $0;
    if (result > 9) {
      _index--;
      if (!throws) return null;
      throw _error("Not an integer");
    }
    while (_index < _source.length) {
      char = _source.codeUnitAt(_index);
      var digit = char ^ $0;
      if (digit <= 9) {
        result = result * 10 + digit;
        _index++;
      } else {
        if (char == $dot || (char | 0x20) == $e /* eE */) {
          // It's a double.
          if (!throws) return null;
          throw _error("Not an integer");
        }
        break;
      }
    }
    return sign >= 0 ? result : -result;
  }

  num expectNum() => _scanNumber(false, true) /*!*/;

  num /*?*/ tryNum() => _scanNumber(false, false);

  double expectDouble() => _scanNumber(true, true) /*!*/;

  double /*?*/ tryDouble() => _scanNumber(true, false);

  num _scanNumber(bool asDouble, bool throws) {
    var char = _nextNonWhitespaceChar();
    var start = _index;
    var index = start + 1;
    var sign = 1;
    if (char == $minus || char == $plus) {
      start = index;
      sign = 0x2c - char; // -1 if '-', +1 if '+'
      if (index < _source.length) {
        char = _source.codeUnitAt(index++);
      } else {
        if (!throws) return null;
        throw _error("Not an number", index);
      }
    }
    var result = char ^ $0;
    if (result > 9) {
      if (!throws) return null;
      throw _error("Not an number", index - 1);
    }
    var isInt = !asDouble;
    while (index < _source.length) {
      char = _source.codeUnitAt(index);
      var digit = char ^ $0;
      if (isInt && digit <= 9) {
        result = result * 10 + digit;
        index++;
      } else if (digit <= 9 ||
          (char | 0x20) == $e ||
          char == $dot ||
          char == $plus ||
          char == $minus) {
        isInt = false;
        index++;
      } else {
        break;
      }
    }
    if (isInt) {
      _index = index;
      return sign >= 0 ? result : -result;
    }
    var slice = _source.substring(start, index);
    var doubleResult = 0.0;
    if (throws) {
      try {
        doubleResult = double.parse(slice);
      } on FormatException catch (e) {
        throw FormatException("Not a number", _source,
            e.offset == null ? null : start + e.offset);
      }
    } else {
      var result = double.tryParse(slice);
      if (result == null) return null;
      doubleResult = result;
    }
    _index = index;
    return sign >= 0 ? doubleResult : -doubleResult;
  }

  int _nextNonWhitespaceChar() {
    while (_index < _source.length) {
      var char = _source.codeUnitAt(_index);
      // Perfect hash for 0x09 (tab), 0x0a (nl), 0x0d (cr) and 0x20 (space).
      var base = char -
          0x9; // 0x00, 0x01, 0x04 or 0x17. Keep this because it only needs 5 bits.
      var hash = (base | (base >> 1)) & 3; // 0x00, 0x01, 0x02 or 0x03
      const table = (0x00 << 0) | (0x01 << 5) | (0x04 << 10) | (0x17 << 15);
      if ((table >> (5 * hash)) & 0x1f == base) {
        _index++;
        continue;
      }
      return char;
    }
    return -1;
  }

  /// Previous non-whitespace character, or -1 if none.
  ///
  /// Does not update [_index].
  /// Only used for error checking in debug mode.
  int _prevNonWhitespaceChar() {
    var index = _index;
    while (index > 0) {
      var char = _source.codeUnitAt(--index);
      // Perfect hash for 0x09 (tab), 0x0a (nl), 0x0d (cr) and 0x20 (space).
      var base = char -
          0x9; // 0x00, 0x01, 0x04 or 0x17. Keep this because it only needs 5 bits.
      var hash = (base | (base >> 1)) & 3; // 0x00, 0x01, 0x02 or 0x03
      const table = (0x00 << 0) | (0x01 << 5) | (0x04 << 10) | (0x17 << 15);
      if ((table >> (5 * hash)) & 0x1f == base) {
        continue;
      }
      return char;
    }
    return -1;
  }

  bool checkNum() {
    var char = _nextNonWhitespaceChar();
    return char == $minus || (char ^ $0) <= 9;
  }

  bool checkBool() {
    var char = _nextNonWhitespaceChar();
    return char == $t || char == $f;
  }

  bool checkString() => _nextNonWhitespaceChar() == $quot;

  bool checkObject() => _nextNonWhitespaceChar() == $lbrace;

  bool checkArray() => _nextNonWhitespaceChar() == $lbracket;

  bool checkNull() => _nextNonWhitespaceChar() == $n;

  void skipAnyValue() {
    _skipValue();
  }

  void _skipValue() {
    var char = _nextNonWhitespaceChar();
    _index++;
    if (char == $lbrace) {
      _skipUntil($rbrace);
    } else if (char == $lbracket) {
      _skipUntil($rbracket);
    } else if (char == $quot) {
      _skipString();
    } else if (char == $minus || char ^ $0 <= 9) {
      _skipNumber();
    } else if (char == $f || char == $t || char == $n) {
      _skipWord();
    } else {
      _index--;
      throw _error("Not a value");
    }
  }

  // Skips past characters that may occur in a number.
  void _skipNumber() {
    while (_index < _source.length) {
      var char = _source.codeUnitAt(_index);
      if (char ^ $0 <= 9 ||
          char == $dot ||
          char | 0x20 == $e ||
          char == $minus ||
          char == $plus) {
        _index++;
      } else {
        break;
      }
    }
  }

  // Skips past letters.
  void _skipWord() {
    while (_index < _source.length) {
      var char = _source.codeUnitAt(_index) | 0x20;
      if (char >= $a && char <= $z) {
        _index++;
      } else {
        break;
      }
    }
  }

  StringSlice /*?*/ expectAnyValueSource() {
    var next = _nextNonWhitespaceChar();
    if (next < 0) return null;
    var start = _index;
    _skipValue();
    var end = _index;
    return StringSlice(_source, start, end);
  }

  String /*?*/ tryString([List<String> candidates]) {
    assert(candidates == null || areSorted(candidates),
        throw ArgumentError.value(candidates, "candidates", "Are not sorted"));
    if (_nextNonWhitespaceChar() == $quot) {
      if (candidates != null) {
        return _tryCandidateString(candidates);
      }
      return _scanString();
    }
    return null;
  }

  JsonStringReader copy() => JsonStringReader._(_source, _index);

  void expectAnyValue(JsonSink sink) {
    var char = _nextNonWhitespaceChar();
    switch (char) {
      case $lbracket:
        _index++;
        sink.startArray();
        while (hasNext()) {
          expectAnyValue(sink);
        }
        sink.endArray();
        return;
      case $lbrace:
        _index++;
        sink.startObject();
        String /*?*/ key;
        while ((key = nextKey()) != null) {
          sink.addKey(key);
          expectAnyValue(sink);
        }
        sink.endObject();
        return;
      case $quot:
        sink.addString(_scanString());
        return;
      case $t:
        assert(_source.startsWith("rue", _index + 1));
        _index += 4;
        sink.addBool(true);
        return;
      case $f:
        assert(_source.startsWith("alse", _index + 1));
        _index += 5;
        sink.addBool(false);
        return;
      case $n:
        assert(_source.startsWith("ull", _index + 1));
        _index += 4;
        sink.addNull();
        return;
      default:
        if (char == $minus || (char ^ 0x30) <= 9) {
          sink.addNumber(_scanNumber(false, true));
          return;
        }
    }
    throw _error("Not a JSON value");
  }
}

class StringSlice {
  /// The original string.
  final String source;

  /// The start of the slice.
  ///
  /// The _index of the first character after the start of the slice.
  final int start;

  /// The end of the slice.
  ///
  /// This is the _index of the first character after the end of the slice.
  final int end;

  /// Creates a slice of [source] from [start] to [end].
  const StringSlice(this.source, this.start, this.end)
      : assert(0 <= start),
        assert(start <= end),
        assert(end <= source.length);

  String toString() => source.substring(start, end);
}
