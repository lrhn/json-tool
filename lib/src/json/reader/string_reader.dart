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

/// A non-validating string-based [JsonReader].
final class JsonStringReader implements JsonReader<StringSlice> {
  /// The source string being read.
  final String _source;

  /// The current position in the _source string.
  int _index;

  /// Creates scanner for JSON [source].
  JsonStringReader(String source) : this._(source, 0);

  /// Used by [copy] to create a copy of this reader's state.
  JsonStringReader._(this._source, this._index);

  FormatException _error(String message, [int? index]) =>
      FormatException(message, _source, index ?? _index);

  @override
  void expectObject() {
    if (!tryObject()) throw _error("Not an object");
  }

  @override
  bool tryObject() {
    var char = _nextNonWhitespaceChar();
    if (char == $lbrace) {
      _index++;
      return true;
    }
    return false;
  }

  @override
  String? nextKey() {
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

  @override
  bool hasNextKey() {
    var nextKey = _nextKeyStart();
    if (nextKey == $rbrace) {
      _index++;
      return false;
    }
    if (nextKey == $quot) {
      return true;
    }
    throw _error("Not a string");
  }

  @override
  StringSlice? nextKeySource() {
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

  @override
  String? tryKey(List<String> candidates) {
    assert(areSorted(candidates),
        throw ArgumentError.value(candidates, "candidates", "Are not sorted"));
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
  /// The candidates must be sorted ASCII strings, and must not be empty.
  String? _tryCandidateString(List<String> candidates) {
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

  @override
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

  @override
  void endObject() {
    _skipUntil($rbrace);
  }

  @override
  void expectArray() {
    if (!tryArray()) throw _error("Not an array");
  }

  @override
  bool tryArray() {
    var char = _nextNonWhitespaceChar();
    if (char == $lbracket) {
      _index++;
      return true;
    }
    return false;
  }

  @override
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

  @override
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

  @override
  String expectString([List<String>? candidates]) {
    assert(candidates == null || candidates.isNotEmpty,
        throw ArgumentError.value(candidates, "candidates", "Are empty"));
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
    StringBuffer? buffer;
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
        buf.write(_source.substring(start, _index - 1));
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
                value = value * 16 + char - ($a - 10);
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

  @override
  bool? tryBool() {
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

  @override
  bool expectBool() => tryBool() ?? (throw _error("Not a boolean"));

  @override
  bool tryNull() {
    var char = _nextNonWhitespaceChar();
    if (char == $n) {
      assert(_source.startsWith("ull", _index + 1));
      _index += 4;
      return true;
    }
    return false;
  }

  @override
  Null expectNull() {
    tryNull() || (throw _error("Not null"));
  }

  @override
  int expectInt() => _scanInt(true)!;

  @override
  int? tryInt() => _scanInt(false);

  int? _scanInt(bool throws) {
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

  @override
  num expectNum() => _scanNumber(false, true)!;

  @override
  num? tryNum() => _scanNumber(false, false);

  @override
  double expectDouble() => _scanNumber(true, true) as dynamic;

  @override
  double? tryDouble() => _scanNumber(true, false) as dynamic;

  num? _scanNumber(bool asDouble, bool throws) {
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
        var offset = e.offset;
        throw FormatException(
            "Not a number", _source, offset == null ? null : start + offset);
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
      if (char <= 0x20) {
        assert(isWhitespace(char), throw _error("Not valid character"));
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
      if (isWhitespace(char)) {
        continue;
      }
      return char;
    }
    return -1;
  }

  @override
  bool checkNum() {
    var char = _nextNonWhitespaceChar();
    return char ^ $0 <= 9 || char == $minus;
  }

  @override
  bool checkBool() {
    var char = _nextNonWhitespaceChar();
    return char == $t || char == $f;
  }

  @override
  bool checkString() => _nextNonWhitespaceChar() == $quot;

  @override
  bool checkObject() => _nextNonWhitespaceChar() == $lbrace;

  @override
  bool checkArray() => _nextNonWhitespaceChar() == $lbracket;

  @override
  bool checkNull() => _nextNonWhitespaceChar() == $n;

  @override
  Null skipAnyValue() {
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
    } else if (char ^ $0 <= 9 || char == $minus) {
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

  @override
  StringSlice expectAnyValueSource() {
    var next = _nextNonWhitespaceChar();
    if (next < 0) return throw _error("Not a value");
    var start = _index;
    _skipValue();
    var end = _index;
    return StringSlice(_source, start, end);
  }

  @override
  String? tryString([List<String>? candidates]) {
    assert(candidates == null || candidates.isNotEmpty,
        throw ArgumentError.value(candidates, "candidates", "Are empty"));
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

  @override
  JsonStringReader copy() => JsonStringReader._(_source, _index);

  @override
  Null expectAnyValue(JsonSink sink) {
    var char = _nextNonWhitespaceChar();
    if (char <= 0x7f) {
      switch (jsonCharacters.codeUnitAt(char)) {
        case 0: // $lbracket:
          _index++;
          sink.startArray();
          while (hasNext()) {
            expectAnyValue(sink);
          }
          sink.endArray();
          return;
        case 1: // $lbrace:
          _index++;
          sink.startObject();
          var key = nextKey();
          while (key != null) {
            sink.addKey(key);
            expectAnyValue(sink);
            key = nextKey();
          }
          sink.endObject();
          return;
        case 2: // $quot:
          sink.addString(_scanString());
          return;
        case 3: // $t:
          assert(_source.startsWith("rue", _index + 1));
          _index += 4;
          sink.addBool(true);
          return;
        case 4: // $f:
          assert(_source.startsWith("alse", _index + 1));
          _index += 5;
          sink.addBool(false);
          return;
        case 5: // $n:
          assert(_source.startsWith("ull", _index + 1));
          _index += 4;
          sink.addNull();
          return;
        case 6: // $0-9, $minus:
          sink.addNumber(_scanNumber(false, true)!);
          return;
      }
    }
    throw _error("Not a JSON value");
  }
}

/// A slice of a larger string.
///
/// Represents the substring of [source] from [start] to [end].
/// Allows some operations on that substring without having to
/// create it as a separate string.
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

  /// length of the string slice.
  int get length => end - start;

  /// A substring of the string slice.
  String substring(int start, [int? end]) {
    end = RangeError.checkValidRange(start, end, this.end - this.start);
    return source.substring(this.start + start, this.start + end);
  }

  /// A sub-slice of the string slice.
  StringSlice subslice(int start, [int? end]) {
    end = RangeError.checkValidRange(start, end, this.end - this.start);
    return StringSlice(source, this.start + start, this.start + end);
  }

  /// The index of the first occurrence of [pattern] in this slice string.
  ///
  /// Returns `-1` if [pattern] does not occur inside this
  /// slice string at a position after [start].
  int indexOf(String pattern, [int start = 0, int? end]) {
    end = RangeError.checkValidRange(start, end, this.end - this.start);
    return _indexOf(pattern, start, end);
  }

  int _indexOf(String pattern, int start, int end) {
    var last = end - pattern.length;
    for (var i = start; i <= last; i++) {
      if (source.startsWith(pattern, this.start + i)) return i;
    }
    return -1;
  }

  /// Whether the slice string contains [pattern].
  bool contains(String pattern) => _indexOf(pattern, 0, end - start) >= 0;

  /// The slice string characters as a separate string.
  @override
  String toString() => source.substring(start, end);
}
