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

import "dart:convert";

import "package:jsontool/jsontool.dart";

const jsonText = """
{
  "version": 1,
  "planets": [
    {"name": "Mercury", "type": "rock", "size": 0.38},
    {"name": "Venus",   "type": "rock", "size": 0.95},
    {"name": "Earth",   "type": "rock", "size": 1.0 },
    {"name": "Mars",    "type": "rock", "size": 0.53},
    {"name": "Saturn",  "type": "gas",  "size": 9.45},
    {"name": "Jupiter", "type": "gas",  "size": 11.2},
    {"name": "Uranus",  "type": "ice",  "size": 4.0 },
    {"name": "Neptune", "type": "ice",  "size": 3.88},
    {"name": "Pluto",   "type": "rock", "size": 0.18}
  ]
}
""";

/// Enumeration of types of planets.
enum PlanetType implements JsonWritable {
  /// The type of gas giants.
  gas("gas", "Gas Giant"),

  /// The type of ice giants.
  ice("ice", "Ice Giant"),

  /// The type of rock based planets.
  rock("rock", "Rock Planet");

  /// String key used to represent the type
  final String key;

  /// A descriptive representation of the type.
  final String description;

  const PlanetType(this.key, this.description);

  /// Look up a planet type by its [PlanetType.key].
  static PlanetType? fromKey(String key) => const {
        "gas": gas,
        "ice": ice,
        "rock": rock,
      }[key];

  static PlanetType readJson(JsonReader reader) {
    var keyIndex = reader.tryStringIndex(const ["gas", "ice", "rock"]);
    if (keyIndex == null) {
      throw reader.fail('Not a planet type: "gas", "ice" or "rock"');
    }
    return values[keyIndex];
  }

  @override
  void writeJson(JsonSink target) {
    target.addString(key);
  }

  @override
  String toString() => description;
}

/// A celestial object orbiting a star.
class Planet implements JsonWritable {
  /// Traditional name of the planet.
  final String name;

  /// Diameter relative to Earth's diameter.
  final double sizeIndex;

  /// The kind of planet.
  final PlanetType type;

  Planet(this.name, this.sizeIndex, this.type);

  @override
  String toString() => name;

  @override
  void writeJson(JsonSink target) {
    target
      ..startObject()
      ..addStringEntry("name", name)
      ..addNumberEntry("size", sizeIndex)
      ..addWritableEntry("name", type)
      ..endObject();
  }

  /// Builds a planet from a JSON object.
  ///
  /// Properties of the object must be:
  /// * `name`: A string.
  /// * `size`: A double.
  /// * `type`: A string. One of `"gas"`, `"ice"` or `"rock"`.
  static Planet readJson(JsonReader reader) {
    reader.expectObject();
    String? name;
    PlanetType? type;
    double? sizeIndex;
    while (reader.hasNextKey()) {
      switch (reader.tryKeyIndex(const ["name", "size", "type"])) {
        case 0: // "name"
          name = reader.tryString() ??
              (throw reader.fail("Planet name must be a string"));
          break;
        case 1: // "size"
          sizeIndex = reader.tryDouble() ??
              (throw reader.fail("Plane size index must be a number"));
          break;
        case 2: // "type"
          type = PlanetType.readJson(reader);
          break;
        default:
          reader.skipObjectEntry();
      }
    }
    // No more entries in JSON object.
    if (name == null) {
      throw reader.fail("Planet missing name");
    }
    if (type == null) {
      throw reader.fail("Planet $name missing type");
    }
    if (sizeIndex == null) {
      throw reader.fail("Planet $name missing size");
    }
    return Planet(name, sizeIndex, type);
  }
}

/// Build planets from a planet registry.
///
/// A planet registry is a JSON object with a
/// `"planets"` entry containing an array of planets.
///
/// It may contain a `"vesion"` entry too. If so, the
/// version number must be the integer `1` until
/// further versions are provided.
List<Planet> buildPlanets(JsonReader reader) {
  reader.expectObject();
  var result = <Planet>[];
  while (true) {
    const planets = 0;
    const version = 1;
    var key = reader.tryKeyIndex(const ["planets", "version"]);
    if (key == version) {
      var version = reader.expectInt();
      if (version != 1) throw FormatException("Unknown version");
    } else if (key == planets) {
      reader.expectArray();
      while (reader.hasNext()) {
        result.add(Planet.readJson(reader));
      }
    } else {
      if (!reader.skipObjectEntry()) {
        // No entries left.
        break;
      }
    }
  }
  return result;
}

/// Example use.
void main() {
  // Reader planets from a JSON string.
  var reader = JsonReader.fromString(jsonText);
  // reader = ValidatingJsonReader(reader); // Convenient while debugging.
  var planets = buildPlanets(reader);

  // Show them.
  for (var planet in planets) {
    var size = planet.sizeIndex;
    var volume = size * size * size;
    print("$planet is a ${planet.type} and has a volume "
        "${volume.toStringAsFixed(2)} times that of the Earth");
  }

  // Read same planets from a UTF-8 encoding.
  var bytes = utf8.encode(jsonText);
  var utf8Reader = JsonReader.fromUtf8(bytes);
  // utf8Reader = ValidatingJsonReader(utf8Reader);
  var planetsAgain = buildPlanets(utf8Reader);

  // The `readJson` methods work on any `JsonReader`, and gives the same result.
  assert(planets.length == planetsAgain.length);
  for (var i = 0; i < planets.length; i++) {
    assert(planets[i].name == planetsAgain[i].name);
    assert(planets[i].sizeIndex == planetsAgain[i].sizeIndex);
    assert(planets[i].type == planetsAgain[i].type);
  }
}
