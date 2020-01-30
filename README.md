# A collection of JSON related operations.

This package contains an *experimental* API for dealing with JSON
encoded data.

This is not an officially supported Google product.

-------

[JSON](https://json.org/) is a text format which can represent a general
"JSON structure". There are many ways to generate JSON text and convert
JSON text to native data structures in most languages.

A JSON structure is either a *primitive value*: a number, a string,
a boolean or a null value, or it is a composite value.
The composite value is either a JSON array, a seqeunce of JSON structures,
or a JSON object, a sequence of pairs of string keys and JSON structure values.

Dart typically represents the JSON structure using `List` and `Map` objects
for the composite values and `num`, `String`, `bool` and `Null` values for
the primitive values.

This package provides various ways to operate on a JSON structure without
necessarily creating intermediate Dart lists or maps.

The `JsonReader` provides a *pull based* approach to investigating and
deconstructing a JSON structure, whether it's represented as a string,
bytes which are the UTF-8 encoding of such a string, or by Dart object
structures.

The `JsonSink` provides a *push based* approach to building
a JSON structure. This can be used to create JSON source or structures
from other kinds of values.

The `JsonBuilder` functions provide a composable way to convert a
JSON structure to another kind of value.
