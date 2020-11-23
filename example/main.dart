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

import "package:jsontool/jsontool.dart";

const jsonText = """
{
  "version": 1,
  "planets": [
    {
      "name": "Mercury",
      "type": "rock",
      "size": 0.38
    },
    {
      "name": "Venus",
      "type": "rock",
      "size": 0.95
    },
    {
      "name": "Earth",
      "type": "rock",
      "size": 1.0
    },
    {
      "name": "Mars",
      "type": "rock",
      "size": 0.53
    },
    {
      "name": "Saturn",
      "type": "gas",
      "size": 9.45
    },
    {
      "name": "Jupiter",
      "type": "gas",
      "size": 11.2
    },
    {
      "name": "Uranus",
      "type": "ice",
      "size": 4.0
    },
    {
      "name": "Neptune",
      "type": "ice",
      "size": 3.88
    },
    {
      "name": "Pluto",
      "type": "rock",
      "size": 0.18
    }
  ]
}
""";

/// Enumeration of types of planets.
class PlanetType {
  /// String key used to represent the type
  final String key;

  /// A descriptive representation of the type.
  final String description;
  const PlanetType._(this.key, this.description);

  /// The type of gas giants.
  static const gas = PlanetType._("gas", "Gas Giant");

  /// The type of ice giants.
  static const ice = PlanetType._("ice", "Ice Giant");

  /// The type of rock based planets.
  static const rock = PlanetType._("rock", "Rock Planet");

  /// Look up a planet type by its [PlanetType.key].
  static PlanetType fromKey(String key) => const {
        "gas": gas,
        "ice": ice,
        "rock": rock,
      }[key];
  String toString() => description;
}

/// A round celestial object smaller than a star.
class Planet {
  /// Traditional name of the planet.
  final String name;

  /// Diameter relative to Earth's diameter.
  final double sizeIndex;

  /// The kind of planet.
  final PlanetType type;

  Planet(this.name, this.sizeIndex, this.type);

  String toString() => name;
}

/// Builds a planet from a JSON object.
///
/// Properties of the object must be:
/// * `name`: A string.
/// * `size`: A double.
/// * `type`: A string. One of `"gas"`, `"ice"` or `"rock"`.
Planet buildPlanet(JsonReader reader) {
  reader.expectObject();
  String name;
  PlanetType type;
  double sizeIndex;
  loop:
  while (true) {
    switch (reader.tryKey(const ["name", "size", "type"])) {
      case "name":
        name = reader.expectString();
        break;
      case "size":
        sizeIndex = reader.expectDouble();
        break;
      case "type":
        var typeString = reader.tryString(const ["gas", "ice", "rock"]);
        if (typeString == null) {
          typeString = reader.tryString();
          throw FormatException(
              "Invalid planet type${typeString == null ? "" : ": $typeString"}");
        }
        type = PlanetType.fromKey(typeString);
        break;
      default:
        if (!reader.skipObjectEntry()) break loop;
    }
  }
  if (name == null) {
    throw FormatException("Planet missing name");
  }
  if (type == null) {
    throw FormatException("Planet $name missing type");
  }
  if (sizeIndex == null) {
    throw FormatException("Planet $name missing size");
  }
  return Planet(name, sizeIndex, type);
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
    var key = reader.tryKey(const ["planets", "version"]);
    if (key == "version") {
      var version = reader.expectInt();
      if (version != 1) throw FormatException("Unknown version");
    } else if (key == "planets") {
      reader.expectArray();
      while (reader.hasNext()) {
        result.add(buildPlanet(reader));
      }
    } else if (!reader.skipObjectEntry()) {
      break;
    }
  }
  return result;
}

/// Example use.
void main(List<String> args) {
  var reader = JsonReader.fromString(jsonText);

  var planets = buildPlanets(reader);
  for (var planet in planets) {
    var size = planet.sizeIndex;
    var volume = size * size * size;
    print("${planet} is a ${planet.type} and has a volume "
        "${volume.toStringAsFixed(2)} times that of the Earth");
  }
}
