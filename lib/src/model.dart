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

import 'dart:convert' show ByteConversionSink, Converter;

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:tuple/tuple.dart' show Tuple2;

import 'package:crclib/src/primitive.dart';
import 'package:crclib/src/primitive_js.dart'
    if (dart.library.io) 'package:crclib/src/primitive_vm.dart';

bool shouldUseBigInt(int width) {
  return width > maxBitwiseOperationLengthInBits();
}

/// The base class of all CRC routines. The parameters are:
///
///   * width: The bit count of the CRC value, eg 32, 16.
///   * polynomial: The generator polynomial in integer form, eg if the
///       polynomial is x^4 + x + 1, its integer form is 0x13 (0b10011). The
///       highest bit of this value can be left out too, eg 0x03.
///   * initialValue: The initial CRC value to start the calculation with.
///   * finalMask: The bit mask to XOR the (possibly reflected) final CRC value.
///   * inputReflected: Whether the input to CRC calculation should be
///       reflected.
///   * outputReflected: Whether the CRC value is reflected before being XOR'd
///       with finalMask.
class ParametricCrc extends Converter<List<int>, CrcValue> {
  static final Map<Tuple2<Comparable, bool>, List<Comparable>>
      _generatedTables = <Tuple2<Comparable, bool>, List<Comparable>>{};

  List<Comparable> _table;
  final int _width;
  final Comparable _polynomial;
  final dynamic _initialValue;
  final dynamic _finalMask;
  final bool _inputReflected;
  final bool _outputReflected;

  ParametricCrc(
      this._width, this._polynomial, this._initialValue, this._finalMask,
      {bool inputReflected = true, bool outputReflected = true})
      : _inputReflected = inputReflected,
        _outputReflected = outputReflected,
        assert((!shouldUseBigInt(_width) &&
                _polynomial is int &&
                _initialValue is int &&
                _finalMask is int) ||
            (shouldUseBigInt(_width) &&
                _polynomial is BigInt &&
                _initialValue is BigInt &&
                _finalMask is BigInt)) {
    // TODO
    assert(_inputReflected == _outputReflected,
        'Different input and output reflection flag is not supported yet.');
    assert((_width % 8) == 0, 'Bit level checksums not supported yet.');

    final key = Tuple2(_polynomial, _inputReflected);
    _table = _generatedTables[key];
    if (_table == null) {
      _table = createByteLookupTable(_width, _polynomial, _inputReflected);
      _generatedTables[key] = _table;
    }
  }

  /// Returns the length in bits of returned CRC values.
  int get lengthInBits => _width;

  @override
  CrcValue convert(List<int> input) {
    final outputSink = FinalSink();
    final inputSink = startChunkedConversion(outputSink);
    inputSink.add(input);
    inputSink.close();
    return outputSink.value;
  }

  @override
  ByteConversionSink startChunkedConversion(Sink<CrcValue> outputSink) {
    ByteConversionSink ret;
    if (_inputReflected) {
      if (shouldUseBigInt(_width)) {
        ret = ReflectedSinkBigInt(_table as List<BigInt>,
            _initialValue as BigInt, _finalMask as BigInt, outputSink, _width);
      } else {
        ret = ReflectedSinkInt(_table as List<int>, _initialValue as int,
            _finalMask as int, outputSink, _width);
      }
    } else {
      if (shouldUseBigInt(_width)) {
        ret = NormalSinkBigInt(_table as List<BigInt>, _initialValue as BigInt,
            _finalMask as BigInt, outputSink, _width);
      } else {
        ret = NormalSinkInt(_table as List<int>, _initialValue as int,
            _finalMask as int, outputSink, _width);
      }
    }
    return ret;
  }
}

/// Creates new lookup table for ONE byte.
///
/// The [poly] value will be truncated to [width] bits. If [reflected] is
/// `true`, the entries in the table will be reflected.
@visibleForTesting
List<Comparable> createByteLookupTable(
    int width, Comparable poly, bool reflected) {
  assert(width >= 8);
  assert(poly is int || poly is BigInt);
  if (poly is int) {
    return _createByteLookupTableInt(width, poly, reflected);
  }
  return _createByteLookupTableBigInt(width, poly as BigInt, reflected);
}

List<Comparable> _createByteLookupTableInt(
    int width, int poly, bool reflected) {
  var ret = createTable(width);
  final widthMask = (1 << width) - 1;
  final truncatedPoly = poly & widthMask;
  final topMask = 1 << (width - 1);
  for (var i = 0; i < 256; ++i) {
    int crc;
    if (reflected) {
      crc = reflectInt(i, 8) << (width - 8);
    } else {
      crc = i << (width - 8);
    }
    for (var j = 0; j < 8; ++j) {
      if ((crc & topMask) != 0) {
        crc = ((crc << 1) ^ truncatedPoly);
      } else {
        crc <<= 1;
      }
    }
    if (reflected) {
      ret[i] = reflectInt(crc, width);
    } else {
      ret[i] = crc & widthMask;
    }
  }
  return ret;
}

List<Comparable> _createByteLookupTableBigInt(
    int width, BigInt poly, bool reflected) {
  var ret = List.filled(256, BigInt.zero, growable: false);
  final widthMask = (BigInt.one << width) - BigInt.one;
  final truncatedPoly = poly & widthMask;
  final topMask = BigInt.one << (width - 1);
  for (var i = 0; i < 256; ++i) {
    BigInt crc;
    if (reflected) {
      crc = BigInt.from(reflectInt(i, 8)) << (width - 8);
    } else {
      crc = BigInt.from(i) << (width - 8);
    }
    for (var j = 0; j < 8; ++j) {
      if ((crc & topMask) != BigInt.zero) {
        crc = ((crc << 1) ^ truncatedPoly);
      } else {
        crc <<= 1;
      }
    }
    if (reflected) {
      ret[i] = reflectBigInt(crc, width);
    } else {
      ret[i] = crc & widthMask;
    }
  }
  return ret;
}
