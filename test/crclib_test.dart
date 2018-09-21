// Copyright 2017 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'package:dart2_constant/convert.dart';

import 'package:test/test.dart';

import 'package:crclib/crclib.dart';

typedef ParametricCrc _ConsFunc();

main() {
  test('reflect', () {
    const inputs = const [0x80, 0xF0, 0xA5];
    const expected = const [0x01, 0x0F, 0xA5];
    final actual = inputs.map((i) => reflect(i, 8));
    expect(actual, expected);
    expect(reflect(0x3e23, 3), 6);
    expect(reflect(0xF000000000000000, 64), 0x0F);
    expect(reflect(0x000000000000000F, 3), 0x7);
  });

  const inputs = const [
    '123456789',
    '1234567890',
    'The quick brown fox jumps over the lazy dog',
  ];

  Future testOneAlgo(_ConsFunc constructor, final List<int> expected) async {
    Iterable<int> actual =
        inputs.map((s) => constructor().convert(utf8.encode(s)));
    expect(actual, expected);

    var futures = inputs.map((s) =>
        new Stream.fromIterable([s.substring(0, 5), s.substring(5)])
            .transform(utf8.encoder)
            .transform(constructor())
            .single);
    actual = await Future.wait(futures);
    expect(actual, expected);
  }

  void testManyAlgos(Map<Function, List<int>> testCases) {
    testCases.forEach((constructor, expected) {
      dynamic obj = constructor();
      test(obj.runtimeType, () async {
        await testOneAlgo(constructor, expected);
      });
    });
  }

  group('crc8', () {
    testManyAlgos({
      () => new Crc8Wcdma(): const [0x25, 0x6E, 0x7F],
      () => new Crc8Atm(): const [0xA1, 0x07, 0x94],
      () => new Crc8Rohc(): const [0xD0, 0xA8, 0xBF],
    });
  });

  group('crc16', () {
    testManyAlgos({
      () => new Crc16Usb(): const [0xB4C8, 0x3DF5, 0x5763],
      () => new Crc16X25(): const [0x906E, 0x4B13, 0x9358],
    });
  });

  group('crc24', () {
    testManyAlgos({
      () => new Crc24OpenPgp(): const [0x21CF02, 0x8c0072, 0xa2618c],
    });
  });

  group('crc32', () {
    testManyAlgos({
      () => new Crc32Zlib(): const [0xCBF43926, 0x261DAEE5, 0x414FA339],
      () => new Crc32Bzip2(): const [0xFC891918, 0x506853B6, 0x459DEE61],
      () => new Crc32Iscsi(): const [0xE3069283, 0xF3DBD4FE, 0x22620404],
    });
  });

  group('crc64', () {
    testManyAlgos({
      () => new Crc64Xz(): const [
        0x995DC9BBDF1939FA,
        0xB1CB31BBB4A2B2BE,
        0x5B5EB8C2E54AA1C4,
      ],
    });
  });
}
