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

import 'dart:async';

import 'package:test/test.dart';
import '../example/planets_json.dart' as planets;
import '../example/bigint_json.dart' as bigint;

const planetsOutput = """
Mercury is a Rock Planet and has a volume 0.05 times that of the Earth
Venus is a Rock Planet and has a volume 0.86 times that of the Earth
Earth is a Rock Planet and has a volume 1.00 times that of the Earth
Mars is a Rock Planet and has a volume 0.15 times that of the Earth
Saturn is a Gas Giant and has a volume 843.91 times that of the Earth
Jupiter is a Gas Giant and has a volume 1404.93 times that of the Earth
Uranus is a Ice Giant and has a volume 64.00 times that of the Earth
Neptune is a Ice Giant and has a volume 58.41 times that of the Earth
Pluto is a Rock Planet and has a volume 0.01 times that of the Earth
""";

const bigintOutput = """
source: {"x":123456789123456789123456789123456789}
big value: 123456789123456789123456789123456789
new source: {"x":123456789123456789123456789123456789}
""";

void main() {
  group("Ensure examples are running:", () {
    test("planets", () {
      expect(capturePrint(planets.main), planetsOutput);
    });
    test("bigint", () {
      expect(capturePrint(bigint.main), bigintOutput);
    });
  });
}

// Captures *synchronous* prints, avoids them going to the console.
String capturePrint(void Function() action) {
  var capture = StringBuffer();
  runZoned(action, zoneSpecification: ZoneSpecification(print: (s, p, z, text) {
    capture.writeln(text);
  }));
  return capture.toString();
}
