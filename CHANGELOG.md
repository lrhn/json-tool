## 2.1.0

- Adds `expectStringIndex`, `tryStringIndex`,  and `tryKeyIndex`
  to `JsonReader. Allows matching a string in a list, like
  the non-`Index` operations, but returns in the position in
  the list instead of the string at that position.
- Adds `JsonReader.fail` which returns a `FormatException`
  at the current position in the reader, with a user provided
  error message.

## 2.0.0

- Require SDK 3.3.0+.
- Adds class modifiers.
- Update lints.

- Change some `void` return types to `Null` in `JsonReader`
  This allows uses like `reader.tryString() ?? reader.expectNull()`
  to match a string or `null`.
- Adds `processObjectEntry` method to `JsonProcessor`, called
  for each object entry.
- Use table to improve parsing speed for `skipAnyValue`.
- Faster whitespace skipping in readers.

## 1.2.0

- Allow SDK 3.0.0+.
- Tweak `ByteWriter` implementation.

## 1.1.3

- Typos fixed.
- Bug in `byte_reader.dart` fixed.

## 1.1.2

- Optimizes to avoid or cheapen `as` casts where possible.
  Uses `as dynamic` with a context type where a cast cannot be avoided,
  for better dart2js performance.

## 1.1.1

- Populate the pubspec's `repository` field.
- Use `package:lints` for linting.
- Adds `processObjectEntry` to `JsonProcessor`.

## 1.1.0

- Null safe.
- Adds `JsonWriter` for JSON sinks which generate JSON-like structures.
  Allows injecting "source" (of a matching format) directly into the structure.
- Adds `JsonProcessor`. Like a `JsonSink` but gets the `JsonReader` so it can
  process the values itself instead of getting the processed value.
- Adds `JsonReader.hasNextKey` and some methods on `StringSlice`.

## 1.0.1

- Add CHANGELOG.md.

## 1.0.0

- Initial Release
