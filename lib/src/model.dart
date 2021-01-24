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

import 'dart:convert'
    show ByteConversionSink, ByteConversionSinkBase, Converter;

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:tuple/tuple.dart' show Tuple2;

import 'package:crclib/src/primitive.dart';
import 'package:crclib/src/primitive_js.dart'
    if (dart.library.io) 'package:crclib/src/primitive_vm.dart';

bool shouldUseBigInt(int width) {
  return width > maxBitwiseOperationLengthInBits();
}

/// The base class of all CRC routines.
abstract class BaseCrc extends Converter<List<int>, CrcValue> {
  final int _width;

  const BaseCrc(this._width);

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
  CrcSink startChunkedConversion(Sink<CrcValue> output);
}

/// The table lookup implementation of all CRC routines. The parameters are:
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
class ParametricCrc extends BaseCrc {
  static final Map<Tuple2<Comparable, bool>, List<Comparable>>
      _generatedTables = <Tuple2<Comparable, bool>, List<Comparable>>{};

  late List<Comparable> _table;
  final Comparable _polynomial;
  final dynamic _initialValue;
  final dynamic _finalMask;
  final bool _inputReflected;
  final bool _outputReflected;

  ParametricCrc(
      int width, this._polynomial, this._initialValue, this._finalMask,
      {bool inputReflected = true, bool outputReflected = true})
      : _inputReflected = inputReflected,
        _outputReflected = outputReflected,
        assert((!shouldUseBigInt(width) &&
                _polynomial is int &&
                _initialValue is int &&
                _finalMask is int) ||
            (shouldUseBigInt(width) &&
                _polynomial is BigInt &&
                _initialValue is BigInt &&
                _finalMask is BigInt)),
        super(width) {
    // TODO
    assert(_inputReflected == _outputReflected,
        'Different input and output reflection flag is not supported yet.');
    assert((width % 8) == 0, 'Bit level checksums not supported yet.');

    final key = Tuple2(_polynomial, _inputReflected);
    _table = _generatedTables.putIfAbsent(
        key, () => createByteLookupTable(width, _polynomial, _inputReflected));
  }

  @override
  CrcValue convert(List<int> input) {
    final outputSink = FinalSink();
    final inputSink = startChunkedConversion(outputSink);
    inputSink.add(input);
    inputSink.close();
    return outputSink.value;
  }

  @override
  ParametricCrcSink startChunkedConversion(Sink<CrcValue> outputSink) {
    ParametricCrcSink ret;
    if (_inputReflected) {
      if (shouldUseBigInt(_width)) {
        ret = ReflectedSinkBigInt(_width, _table as List<BigInt>,
            _initialValue as BigInt, _finalMask as BigInt, outputSink);
      } else {
        ret = ReflectedSinkInt(
          _width,
          _table as List<int>,
          _initialValue as int,
          _finalMask as int,
          outputSink,
        );
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

/// A dummy CRC function that concatenates a list of others. Other than
/// [lengthInBits], other CRC parameters are not used and should not be trusted.
class MultiCrc extends BaseCrc {
  final List<ParametricCrc> _underlyingCrcs;

  MultiCrc(this._underlyingCrcs)
      : assert(_underlyingCrcs.isNotEmpty),
        super(
            _underlyingCrcs.map((c) => c.lengthInBits).reduce((a, b) => a + b));

  @override
  _MultiCrcSink startChunkedConversion(Sink<CrcValue> outputSink) {
    final finalSinks = List.generate(_underlyingCrcs.length, (_) => FinalSink(),
        growable: false);
    final crcSinks = List<CrcSink>.generate(_underlyingCrcs.length,
        (i) => _underlyingCrcs[i].startChunkedConversion(finalSinks[i]),
        growable: false);
    return _MultiCrcSink(_underlyingCrcs, finalSinks, crcSinks, outputSink);
  }
}

class _MultiCrcSink extends CrcSink {
  final Sink<CrcValue> outputSink;
  final List<FinalSink> underlyingOutputs;
  final List<CrcSink> underlyingSinks;
  final List<BaseCrc> underlyingCrcs;

  _MultiCrcSink(this.underlyingCrcs, this.underlyingOutputs,
      this.underlyingSinks, this.outputSink)
      : assert(underlyingCrcs.length == underlyingOutputs.length &&
            underlyingCrcs.length == underlyingSinks.length),
        super(
            underlyingCrcs.map((c) => c.lengthInBits).reduce((a, b) => a + b));

  @override
  void iterateBytes(Iterable<int> chunk) {
    underlyingSinks.forEach((s) => s.iterateBytes(chunk));
  }

  @override
  void close() {
    underlyingSinks.forEach((s) => s.close());
    var ret = BigInt.zero;
    for (var i = 0; i < underlyingCrcs.length; ++i) {
      var crc = underlyingCrcs[i];
      ret = (ret << crc.lengthInBits) | underlyingOutputs[i].value.toBigInt();
    }
    outputSink.add(CrcValue(ret));
  }

  @override
  _MultiCrcSink split(Sink<CrcValue> outputSink) {
    final finalSinks = List.generate(underlyingCrcs.length, (_) => FinalSink(),
        growable: false);
    final crcSinks = List<CrcSink>.generate(
        underlyingCrcs.length, (i) => underlyingSinks[i].split(finalSinks[i]),
        growable: false);
    return _MultiCrcSink(underlyingCrcs, finalSinks, crcSinks, outputSink);
  }
}
