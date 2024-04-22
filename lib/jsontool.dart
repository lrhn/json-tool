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

/// A collection of JSON related operations.
///
/// [JSON](https://json.org/) is a text format which can represent a general
/// "JSON structure". There are many ways to generate JSON text and convert
/// JSON text to native data structures in most languages.
///
/// A JSON structure is either a *primitive value*: a number, a string,
/// a boolean or a null value, or it is a composite value.
/// The composite value is either a JSON array, a seqeunce of JSON structures,
/// or a JSON object, a sequence of pairs of string keys and JSON structure values.
///
/// Dart typically represents the JSON structure using [List] and [Map] objects
/// for the composite values and [num], [String], [bool] and [Null] values for
/// the primitive values.
///
/// This package provides various ways to operate on a JSON structure without
/// necessarily creating intermediate Dart lists or maps.
///
/// The [JsonReader] provides a *pull based* approach to investigating and
/// deconstructing a JSON structure, whether it's represented as a string,
/// bytes which are the UTF-8 encoding of such a string, or by Dart object
/// structures.
///
/// The [JsonSink] provides a *push based* approach to building
/// a JSON structure. This can be used to create JSON source or structures
/// from other kinds of values.
///
/// The [JsonBuilder] functions provide a composable way to convert a
/// JSON structure to another kind of value.
library jsontool;

export "src/jsontool.dart";
