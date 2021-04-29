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
