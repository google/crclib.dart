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
import 'dart:convert';

import 'package:test/test.dart';

import 'package:crclib/crclib.dart';
import 'package:crclib/src/model.dart' show createByteLookupTable;
import 'package:crclib/src/primitive.dart'
    show CrcValue, reflectBigInt, reflectInt;
import 'package:crclib/src/primitive_js.dart'
if (dart.library.io) 'package:crclib/src/primitive_vm.dart'
    show maxBitwiseOperationLengthInBits;
import 'package:crclib/catalog.dart';

typedef _ConsFunc = ParametricCrc Function();

void main() {
  test('reflect', () {
    const inputs = [0x80, 0xF0, 0xA5];
    const expected = [0x01, 0x0F, 0xA5];
    final actual = inputs.map((i) => reflectInt(i, 8));
    expect(actual, expected);
    expect(reflectInt(0x3e23, 3), 6);
    expect(reflectBigInt(BigInt.parse('F000000000000000', radix: 16), 64),
        BigInt.from(0x0F));
    expect(reflectInt(0x000000000000000F, 3), 0x7);
  });

  const inputs = [
    '123456789',
    '1234567890',
    'The quick brown fox jumps over the lazy dog',
  ];

  Future testOneAlgo(
      _ConsFunc constructor, final List<Comparable> expected) async {
    var expectedCrcValues =
        expected.map((v) => CrcValue(v)).toList(growable: false);
    var actual = inputs.map((s) => constructor().convert(utf8.encode(s)));
    expect(actual, expectedCrcValues);

    var futures = inputs.map((s) =>
        Stream.fromIterable([s.substring(0, 5), s.substring(5)])
            .transform(utf8.encoder)
            .transform(constructor())
            .single);
    actual = await Future.wait(futures);
    expect(actual, expectedCrcValues);
  }

  void testManyAlgos(Map<_ConsFunc, List<Comparable>> testCases) {
    testCases.forEach((constructor, expected) {
      dynamic obj = constructor();
      test(obj.runtimeType, () async {
        await testOneAlgo(constructor, expected);
      });
    });
  }

  group('crc8', () {
    testManyAlgos({
      () => Crc8Wcdma(): [0x25, 0x6E, 0x7F],
      () => Crc8I4321(): [0xA1, 0x07, 0x94],
      () => Crc8Rohc(): [0xD0, 0xA8, 0xBF],
    });
  });

  group('crc16', () {
    testManyAlgos({
      () => Crc16Usb(): [0xB4C8, 0x3DF5, 0x5763],
      () => Crc16X25(): [0x906E, 0x4B13, 0x9358],
    });
  });

  group('crc24', () {
    testManyAlgos({
      () => Crc24OpenPgp(): [0x21CF02, 0x8c0072, 0xa2618c],
    });
  });

  group('crc32', () {
    testManyAlgos({
      () => Crc32Xz(): [0xCBF43926, 0x261DAEE5, 0x414FA339],
      () => Crc32Bzip2(): [0xFC891918, 0x506853B6, 0x459DEE61],
      () => Crc32Iscsi(): [0xE3069283, 0xF3DBD4FE, 0x22620404],
    });
  });

  group('crc64', () {
    testManyAlgos({
      () => Crc64Xz(): [
        BigInt.parse('995DC9BBDF1939FA', radix: 16),
        BigInt.parse('B1CB31BBB4A2B2BE', radix: 16),
        BigInt.parse('5B5EB8C2E54AA1C4', radix: 16),
      ],
      () => Crc64Ecma182(): [
        BigInt.parse('6C40DF5F0B497347', radix: 16),
        BigInt.parse('27B28F2E2139D6A1', radix: 16),
        BigInt.parse('41E05242FFA9883B', radix: 16),
      ],
      () => Crc64WE(): [
        BigInt.parse('62EC59E3F1A4F00A', radix: 16),
        BigInt.parse('4F7CBCEA432C761E', radix: 16),
        BigInt.parse('BCD8BB366D256116', radix: 16),
      ]
    });
  });

  test('reflected crc with initial value different from its own reflection',
      () {
    // TMS37157.
    final init = 0x89ec;
    assert(reflectInt(init, 16) != init);
    final crc = ParametricCrc(16, 0x1021, init, 0x00,
        inputReflected: true, outputReflected: true);
    expect(crc.convert(utf8.encode('123456789')), CrcValue(0x26b1));
  });

  test('createByteLookupTable', () {
    var l1 =
        createByteLookupTable(32, BigInt.parse('42F0E1EB', radix: 16), true);
    var l2 = createByteLookupTable(32, 0x42F0E1EB, true);
    for (var i = 0; i < l1.length; ++i) {
      expect(l1[i], BigInt.from(l2[i] as int));
    }
  });

  group('CrcValue', () {
    var i = 42;
    var iCv = CrcValue(i);
    var sbi = BigInt.from(42);
    var sbiCv = CrcValue(sbi);
    var lbi = BigInt.one << 1024;
    var lbiCv = CrcValue(lbi);
    var m1 = -1;
    var m1Cv = CrcValue((1 << maxBitwiseOperationLengthInBits()) - 1);
    var m1BiCv = CrcValue(
        (BigInt.one << maxBitwiseOperationLengthInBits()) - BigInt.one);

    test('equal int', () {
      expect(i, iCv);
      expect(i, sbiCv);
      expect(i, isNot(lbiCv));
      expect(m1, m1Cv);
      expect(m1, m1BiCv);
    });
    test('equal small BigInt', () {
      expect(sbi, iCv);
      expect(sbi, sbiCv);
      expect(sbi, isNot(lbiCv));
    });
    test('equal large BigInt', () {
      expect(lbi, isNot(iCv));
      expect(lbi, isNot(sbiCv));
      expect(lbi, lbiCv);
    });
    test('equal CrcValue', () {
      expect(lbiCv, lbiCv);
      expect(lbiCv, isNot(iCv));
      expect(lbiCv, isNot(sbiCv));
      expect(iCv, iCv);
      expect(iCv, sbiCv);
      expect(sbiCv, sbiCv);
      expect(m1Cv, m1BiCv);
    });
    test('equal dynamic', () {
      expect('abc', isNot(iCv));
      expect(1.0, isNot(sbiCv));
      expect(<dynamic>[], isNot(lbiCv));
    });
    test('toRadixString', () {
      expect('42', iCv.toRadixString(10));
      expect('101010', sbiCv.toRadixString(2));
      var l = lbiCv.toRadixString(16);
      expect(l.length, 257);
      expect(l[0], '1');
      expect(l.substring(1), List.filled(256, '0').join(''));
    });
    test('toString', () {
      expect('42', iCv.toString());
      expect('42', sbiCv.toString());
      expect(lbi.toString(), lbiCv.toString());
    });
  });
}
