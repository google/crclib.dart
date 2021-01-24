// Copyright 2020 Google Inc.
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

import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:crclib/catalog.dart';
import 'package:crclib/crclib.dart';
import 'package:crclib/src/flipper.dart';

void expectSolution(int width, List<BigInt> checksums, BigInt target) {
  var matrix = generateAugmentedMatrix(width, checksums, target);
  var selected = solveAugmentedMatrix(matrix)!;

  var calculated = 0;
  for (var i = 0; i < checksums.length; ++i) {
    if (selected[i]) {
      calculated ^= checksums[i].toInt();
    }
  }

  expect(calculated, target.toInt());
}

void expectNoSolution(int width, List<BigInt> checksums, BigInt target) {
  var matrix = generateAugmentedMatrix(width, checksums, target);
  var selected = solveAugmentedMatrix(matrix);
  expect(selected, null);
}

void testFlipper(
    ParametricCrc crc, String input, int low, int high, CrcValue target) {
  var flipper = CrcFlipper(crc);
  var data = Uint8List.fromList(input.codeUnits);
  var positions = flipper.flipWithData(
      data, List.generate(high - low + 1, (i) => i + low).toSet(), target)!;
  expect(positions, isNotNull);
  expect(positions, isNotEmpty);
  expect(positions.length, lessThanOrEqualTo(crc.lengthInBits));

  positions.forEach((p) {
    var mask = 1 << (p % 8);
    data[p ~/ 8] ^= mask;
  });

  expect(crc.convert(data), target);
}

void main() {
  test('BitVector', () {
    var oneInt = BitArray(32);
    var twoInts = BitArray(64);
    oneInt[0] = true;
    expect(oneInt[0], true);
    expect(oneInt[31], false);
    twoInts[0] = true;
    twoInts[32] = true;
    expect(twoInts[0], true);
    expect(twoInts[31], false);
    expect(twoInts[32], true);
    expect(twoInts[63], false);
    expect(oneInt.length, 32);
    expect(twoInts.length, 64);
    expect(() => BitArray(-1), throwsArgumentError);
    expect(() => oneInt[-1], throwsRangeError);
    expect(() => oneInt[32], throwsRangeError);
    expect(() => twoInts.clear(), throwsUnsupportedError);
  });

  group('BitMatrix', () {
    test('constructor & access', () {
      var matrix = BitMatrix(4, 2);
      expect(matrix.length, 4);
      expect(matrix[0].length, 2);
      matrix[0][0] = true;
      matrix[3][1] = true;
      expect(matrix[1][0], false);
      expect(matrix[1][1], false);
      expect(matrix[0][0], true);
      expect(matrix[3][1], true);
      expect(() => BitMatrix(-1, 0), throwsArgumentError);
      expect(() => BitMatrix(0, -1), throwsArgumentError);
      expect(() => matrix[-1], throwsRangeError);
      expect(() => matrix[4], throwsRangeError);
      expect(() => matrix.clear(), throwsUnsupportedError);
    });

    test('eliminate', () {
      var matrix = BitMatrix(3, 3);
      matrix[0][0] = true;
      matrix[1][1] = true;
      matrix[2][2] = true;
      expect(matrix.eliminate(), matrix.eliminate());
      expect(matrix.eliminate(), [0, 1, 2]);
      matrix.reset();
      matrix[2][0] = true;
      matrix[1][1] = true;
      matrix[0][2] = true;
      expect(matrix.eliminate(), matrix.eliminate());
      expect(matrix.eliminate(), [0, 1, 2]);
      matrix = BitMatrix(3, 4);
      matrix[0].fillRange(0, 4, true);
      matrix[1].fillRange(2, 4, true);
      expect(matrix.eliminate(), [0, 2, -1]);
      matrix.reset();
      matrix[0].fillRange(0, 4, true);
      matrix[1].fillRange(2, 4, true);
      matrix[2].fillRange(0, 4, true);
      expect(matrix.eliminate(), [0, 2, -1]);
    });
  });

  group('generate & solve matrices', () {
    test('has solutions', () {
      expectSolution(
          4, [9, 2, 4, 8].map((i) => BigInt.from(i)).toList(), BigInt.from(5));
      expectSolution(
          4, [9, 2, 4, 8].map((i) => BigInt.from(i)).toList(), BigInt.from(7));
      expectSolution(
          4, [9, 2, 4, 8].map((i) => BigInt.from(i)).toList(), BigInt.from(0));
    });
    test('has no solutions', () {
      expectNoSolution(
          4, [9, 2, 4].map((i) => BigInt.from(i)).toList(), BigInt.from(1));
      expectNoSolution(
          4, [9, 2, 4].map((i) => BigInt.from(i)).toList(), BigInt.from(3));
      expectNoSolution(
          4, [9, 2, 4].map((i) => BigInt.from(i)).toList(), BigInt.from(5));
      expectNoSolution(
          4, [9, 2, 4].map((i) => BigInt.from(i)).toList(), BigInt.from(7));
      expectNoSolution(
          4, [9, 2, 4].map((i) => BigInt.from(i)).toList(), BigInt.from(8));
    });
  });

  group('CrcFlipper', () {
    group('reflected', () {
      var crcFuncs = <ParametricCrc>[
        Crc16Kermit(), // input reflected
        Crc16B(), // input reflected + init + final mask
      ];
      crcFuncs.forEach((crc) {
        test(crc.runtimeType,
            () => testFlipper(crc, '1234', 16, 31, CrcValue(0xba55)));
      });
    });
    group('regular', () {
      var crcFuncs = <ParametricCrc>[
        Crc16GeniBus(), // not reflected + init + final mask
        Crc16Profibus(), // not reflected + init + final mask
        Crc16LJ1200(), // not reflected
      ];
      crcFuncs.forEach((crc) {
        test(crc.runtimeType,
            () => testFlipper(crc, '1234', 16, 31, CrcValue(0xba55)));
      });
    });
    test('fun', () {
      var inputMessage =
          'flipping lowercases to uppercases like mama pig making hot pancakes '
          'for daddy pig in peppa pig cartoon';
      // Mark the lower/upper-case bit in each character.
      // 0x61 = 'a' = 0110 0001
      //                | <-- 5th bit, zero-indexed
      // 0x41 = 'A' = 0100 0001
      var positions = inputMessage.codeUnits
          .asMap()
          .entries
          .where((e) => e.value >= 0x61 && e.value < 0x61 + 26)
          .map((e) => e.key * 8 + 5)
          .toSet();
      var crc = Crc64();
      var flipper = CrcFlipper(crc);
      var target = BigInt.parse('DEADBEEFCAFEBABE', radix: 16);
      var solution = flipper.flipWithData(
          inputMessage.codeUnits, positions, CrcValue(target))!;
      var tmp = List.of(inputMessage.codeUnits, growable: false);
      solution.forEach((bitPosition) {
        var mask = 1 << (bitPosition % 8);
        tmp[bitPosition ~/ 8] ^= mask;
      });
      expect(target, crc.convert(tmp));
      var outputMessage = String.fromCharCodes(tmp);
      expect(
          outputMessage,
          'flIPpiNG LOWErcAsEs To uPpERcaseS LIkE mAmA Pig mAKInG hOT paNcAKEs '
          'For DAdDY pig in peppa pig cartoon');
    });
    group('multi crc fun', () {
      test('< 64 bits', () {
        var inputMessage =
            'flipping lowercases to uppercases like mama pig making hot pancakes '
            'for daddy pig in peppa pig cartoon';
        var positions = inputMessage.codeUnits
            .asMap()
            .entries
            .where((e) => e.value >= 0x61 && e.value < 0x61 + 26)
            .map((e) => e.key * 8 + 5)
            .toSet();
        var crc = MultiCrc([Crc16(), Crc32()]);
        var flipper = CrcFlipper(crc);
        var target = BigInt.parse('DEADCAFEBEEF', radix: 16);
        var solution = flipper.flipWithData(
            inputMessage.codeUnits, positions, CrcValue(target))!;
        var tmp = List.of(inputMessage.codeUnits, growable: false);
        solution.forEach((bitPosition) {
          var mask = 1 << (bitPosition % 8);
          tmp[bitPosition ~/ 8] ^= mask;
        });
        expect(target, crc.convert(tmp));
        var outputMessage = String.fromCharCodes(tmp);
        expect(
            outputMessage,
            'flIpPIng lowErCaSES TO uPPERCASes LIKE maMa piG MAKINg hot paNcakes '
            'for daddy pig in peppa pig cartoon');
        expect(0xDEAD, Crc16().convert(tmp));
        expect(0xCAFEBEEF, Crc32().convert(tmp));
      });
      test('> 64 bits', () {
        var inputMessage = 'flipping lowercases to UPPERCASES';
        var positions = inputMessage.codeUnits
            .asMap()
            .entries
            .where((e) =>
                (e.value >= 0x61 && e.value < 0x61 + 26) ||
                (e.value >= 0x41 && e.value < 0x41 + 26))
            .map((e) => e.key * 8 + 5)
            .toSet();
        var crc = MultiCrc([Crc16(), Crc32C(), Crc64Xz()]);
        var target = crc
            .convert('flipping LOWERCASES to uppercases'.codeUnits)
            .toBigInt();
        var flipper = CrcFlipper(crc);
        var solution = flipper.flipWithData(
            inputMessage.codeUnits, positions, CrcValue(target))!;
        var tmp = List.of(inputMessage.codeUnits, growable: false);
        solution.forEach((bitPosition) {
          var mask = 1 << (bitPosition % 8);
          tmp[bitPosition ~/ 8] ^= mask;
        });
        expect(target, crc.convert(tmp));
        var outputMessage = String.fromCharCodes(tmp);
        expect(outputMessage, 'flipping LOWERCASES to uppercases');
      });
    });
  });
}
