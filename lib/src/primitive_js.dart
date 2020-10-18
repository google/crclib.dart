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
import 'package:crclib/src/primitive.dart'
    show CrcLoopFunction, CrcValue, NormalSink, ReflectedSink, reflectInt;

int maxBitwiseOperationLengthInBits() {
  // JavaScript only performs shifts and bitwise operators on 32-bit ints.
  return 32;
}

List<Comparable> createTable(int width) {
  List<Comparable> ret;
  if (width <= 8) {
    ret = Uint8List(256);
  } else if (width <= 16) {
    ret = Uint16List(256);
  } else if (width <= 32) {
    ret = Uint32List(256);
  } else {
    ret = List.filled(256, BigInt.zero, growable: false);
  }
  return ret;
}

class NormalSinkInt extends NormalSink<int> {
  NormalSinkInt(List<int> table, int value, int finalMask,
      Sink<CrcValue> outputSink, int width)
      : super(table, value, finalMask, outputSink, width);

  void _crc8Loop(Iterable<int> chunk) {
    for (final b in chunk) {
      value = table[value ^ b];
    }
  }

  void _crc16Loop(Iterable<int> chunk) {
    for (final b in chunk) {
      value = table[(value >> 8) ^ b] ^ ((value << 8) & 0xFFFF);
    }
  }

  void _crc24Loop(Iterable<int> chunk) {
    for (final b in chunk) {
      value = table[(value >> 16) ^ b] ^ ((value << 8) & 0xFFFFFF);
    }
  }

  void _crc32Loop(Iterable<int> chunk) {
    for (final b in chunk) {
      value = table[(value >> 24) ^ b] ^ ((value << 8) & 0xFFFFFFFF);
    }
  }

  void _crcLoop(Iterable<int> chunk) {
    final shiftWidth = width - 8;
    final mask = (1 << width) - 1;
    for (final b in chunk) {
      value = table[((value >> shiftWidth) ^ b) & 0xFF] ^ ((value << 8) & mask);
    }
  }

  @override
  CrcLoopFunction selectLoopFunction() {
    switch (width) {
      case 32:
        return _crc32Loop;
      case 24:
        return _crc24Loop;
      case 16:
        return _crc16Loop;
      case 8:
        return _crc8Loop;
      default:
        return _crcLoop; // XXX: unused.
    }
  }

  @override
  NormalSinkInt split(Sink<CrcValue> outputSink) {
    return NormalSinkInt(table, value, finalMask, outputSink, width);
  }
}

class ReflectedSinkInt extends ReflectedSink<int> {
  ReflectedSinkInt(int width, List<int> table, int value, int finalMask,
      Sink<CrcValue> outputSink)
      : super(width, table, reflectInt(value, width), finalMask, outputSink);

  void _crc8Loop(Iterable<int> chunk) {
    for (final b in chunk) {
      value = table[value ^ b];
    }
  }

  void _crcLoop(Iterable<int> chunk) {
    for (final b in chunk) {
      value = table[(value ^ b) & 0xFF] ^ ((value >> 8) & 0x00FFFFFF);
    }
  }

  @override
  CrcLoopFunction selectLoopFunction() {
    return (width <= 8) ? _crc8Loop : _crcLoop;
  }

  @override
  ReflectedSinkInt split(Sink<CrcValue> outputSink) {
    return ReflectedSinkInt(
        width, table, reflectInt(value, width), finalMask, outputSink);
  }
}
