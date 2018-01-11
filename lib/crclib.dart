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

/// Generic CRC calculations as Dart converters and some common algorithms.
///
/// The easiest way to use this library is to call `convert` on the instance of
/// the desired CRC routine.
///
///   new Crc32Zlib().convert(UTF8.encode('123456789')) == 0xCBF43926
///
/// Another supported use case is as stream transformers.
///
///   new File(...).openRead().transform(new Crc32Zlib())
///
/// Instead of using predefined classes, it is also possible to construct a
/// customized CRC function with [ParametricCrc] class. For a list of known
/// CRC routines, check out http://reveng.sourceforge.net/crc-catalogue/all.htm.
///
/// TODO:
///   1. inputReflected and outputReflected can be different, see CRC-12/UMTS.
///   2. Bit-level checksums (including non-multiple-of-8 checksums).

import 'dart:convert'
    show ByteConversionSink, ByteConversionSinkBase, Converter;

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:tuple/tuple.dart' show Tuple2;

/// Ultimate sink that stores the final CRC value.
class _FinalSink extends Sink<int> {
  int _value;

  int get value {
    assert(_value != null);
    return _value;
  }

  @override
  void add(int data) {
    // Can only be called once.
    assert(_value == null);
    _value = data;
  }

  @override
  void close() {
    assert(_value != null);
  }
}

/// Intermediate sink that performs the actual CRC calculation. It outputs to
/// [_FinalSink].
abstract class _CrcSink extends ByteConversionSinkBase {
  final List<int> _table;
  final int _finalMask;
  final Sink<int> _outputSink;
  CrcLoopFunction _loopFunction;
  int _value;
  bool _closed;

  _CrcSink(
      this._table, this._value, this._finalMask, this._outputSink, int width)
      : _closed = false {
    _loopFunction = _selectLoopFunction(width);
  }

  @override
  void add(List<int> chunk) {
    addSlice(chunk, 0, chunk.length, false /* isLast */);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    _loopFunction(chunk, start, end);
    if (isLast) {
      close();
    }
  }

  @override
  void close() {
    if (!_closed) {
      _closed = true;
      _outputSink.add(_value ^ _finalMask);
      _outputSink.close();
    }
  }

  CrcLoopFunction _selectLoopFunction(int width);
}

typedef void CrcLoopFunction(List<int> chunk, int start, int end);

/// "Normal" CRC routines where the high bits are shifted out to the left.
///
/// The various [CrcLoopFunction] definitions are to optimize for different
/// integer sizes in Dart VM. See "Optimally shifting to the left" in
/// https://www.dartlang.org/articles/dart-vm/numeric-computation.
///
// Note for maintainers: Try not to call any function in these loops. Function
// calls require boxing and unboxing.
class _NormalSink extends _CrcSink {
  _NormalSink(_table, _value, _finalMask, _outputSink, int width)
      : super(_table, _value, _finalMask, _outputSink, width);

  void _crc8Loop(List<int> chunk, int start, int end) {
    for (int b in chunk.getRange(start, end)) {
      _value = _table[_value ^ b];
    }
  }

  void _crc16Loop(List<int> chunk, int start, int end) {
    for (int b in chunk.getRange(start, end)) {
      _value = _table[(_value >> 8) ^ b] ^ ((_value << 8) & 0xFFFF);
    }
  }

  void _crc24Loop(List<int> chunk, int start, int end) {
    for (int b in chunk.getRange(start, end)) {
      _value = _table[(_value >> 16) ^ b] ^ ((_value << 8) & 0xFFFFFF);
    }
  }

  void _crc32Loop(List<int> chunk, int start, int end) {
    for (int b in chunk.getRange(start, end)) {
      _value = _table[(_value >> 24) ^ b] ^ ((_value << 8) & 0xFFFFFFFF);
    }
  }

  void _crc64Loop(List<int> chunk, int start, int end) {
    for (int b in chunk.getRange(start, end)) {
      _value = _table[((_value >> 56) & 0xFF) ^ b] ^
          ((_value << 8) & 0xFFFFFFFFFFFFFFFF);
    }
  }

  @override
  CrcLoopFunction _selectLoopFunction(int width) {
    void _crcLoop(List<int> chunk, int start, int end) {
      int shiftWidth = width - 8;
      int mask = (1 << width) - 1;
      for (int b in chunk.getRange(start, end)) {
        _value = _table[((_value >> shiftWidth) ^ b) & 0xFF] ^
            ((_value << 8) & mask);
      }
    }

    switch (width) {
      case 64:
        return _crc64Loop;
      case 32:
        return _crc32Loop;
      case 24:
        return _crc24Loop;
      case 16:
        return _crc16Loop;
      case 8:
        return _crc8Loop;
      default:
        return _crcLoop;
    }
  }
}

/// "Reflected" CRC routines.
///
/// The specialized loop functions are meant to speed up calculations
/// according to the width of the CRC value.
class _ReflectedSink extends _CrcSink {
  _ReflectedSink(_table, _value, _finalMask, _outputSink, int width)
      : super(_table, _value, _finalMask, _outputSink, width);

  void _crc8Loop(List<int> chunk, int start, int end) {
    for (int b in chunk.getRange(start, end)) {
      _value = (_table[_value ^ b]);
    }
  }

  void _crcLoop(List<int> chunk, int start, int end) {
    for (int b in chunk.getRange(start, end)) {
      _value =
          (_table[(_value ^ b) & 0xFF] ^ ((_value >> 8) & 0xFFFFFFFFFFFFFF));
    }
  }

  CrcLoopFunction _selectLoopFunction(int width) {
    return width <= 8 ? _crc8Loop : _crcLoop;
  }
}

/// Reflects the least [width] bits of input value [i].
///
/// For example: the value of `_reflect(0x80, 8)` is 0x01 because 0x80 is
/// 10000000 in binary; its reflected binary value is 00000001, which is 0x01 in
/// hexadecimal. And `_reflect(0x3e23, 3)` is 6 because the least significant 3
/// bits are 011, when reflected is 110, which is 6 in decimal.
@visibleForTesting
int reflect(int i, int width) {
  int ret = 0;
  while (width-- > 0) {
    ret = (ret << 1) | (i & 1);
    i >>= 1;
  }
  return ret;
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
class ParametricCrc extends Converter<List<int>, int> {
  static Map<Tuple2<int, bool>, List<int>> _generatedTables =
      new Map<Tuple2<int, bool>, List<int>>();

  List<int> _table;
  final int _width;
  final int _polynomial;
  final int _initialValue;
  final int _finalMask;
  final bool _inputReflected;
  final bool _outputReflected;

  ParametricCrc(
      this._width, this._polynomial, this._initialValue, this._finalMask,
      {inputReflected = true, outputReflected = true})
      : _inputReflected = inputReflected,
        _outputReflected = outputReflected {
    // TODO
    assert(_inputReflected == _outputReflected,
        "Different input and output reflection flag is not supported yet.");
    assert((_width % 8) == 0, "Bit level checksums not supported yet.");

    final key = new Tuple2(_polynomial, _inputReflected);
    _table = _generatedTables[key];
    if (_table == null) {
      _table = _createByteLookupTable(_width, _polynomial, _inputReflected);
      _generatedTables[key] = _table;
    }
  }

  @override
  int convert(List<int> input) {
    final outputSink = new _FinalSink();
    final inputSink = startChunkedConversion(outputSink);
    inputSink.add(input);
    inputSink.close();
    return outputSink.value;
  }

  @override
  ByteConversionSink startChunkedConversion(Sink<int> outputSink) {
    ByteConversionSink ret;
    if (_inputReflected) {
      ret = new _ReflectedSink(
          _table, _initialValue, _finalMask, outputSink, _width);
    } else {
      ret = new _NormalSink(
          _table, _initialValue, _finalMask, outputSink, _width);
    }
    return ret;
  }
}

/// Creates new lookup table for ONE byte.
///
/// The [poly] value will be truncated to [width] bits. If [reflected] is
/// `true`, the entries in the table will be reflected.
List<int> _createByteLookupTable(int width, int poly, bool reflected) {
  List<int> ret = new List.filled(256, 0);
  int widthMask = (1 << width) - 1;
  int truncatedPoly = poly & widthMask;
  int topMask = 1 << (width - 1);
  for (int i = 0; i < 256; ++i) {
    int crc;
    if (reflected) {
      crc = reflect(i, 8) << (width - 8);
    } else {
      crc = i << (width - 8);
    }
    for (int j = 0; j < 8; ++j) {
      if ((crc & topMask) != 0) {
        crc = ((crc << 1) ^ truncatedPoly);
      } else {
        crc <<= 1;
      }
    }
    if (reflected) {
      ret[i] = reflect(crc, width);
    } else {
      ret[i] = crc & widthMask;
    }
  }
  return ret;
}

// Below are well-known CRC models.
// Naming convention: Crc<width><app> where <width> is the bit count, and <app>
// is a well-known use of the routine. Please specify both fields even if the
// algorithm is only used by one thing.

/// CRC-64 variant used in XZ utils.
class Crc64Xz extends ParametricCrc {
  Crc64Xz()
      : super(64, 0x42F0E1EBA9EA3693, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
}

/// CRC-32 variant used in Zlib.
class Crc32Zlib extends ParametricCrc {
  Crc32Zlib() : super(32, 0x04C11DB7, 0xFFFFFFFF, 0xFFFFFFFF);
}

/// CRC-32 variant used in Bzip2.
class Crc32Bzip2 extends ParametricCrc {
  Crc32Bzip2()
      : super(32, 0x04C11DB7, 0xFFFFFFFF, 0xFFFFFFFF,
            inputReflected: false, outputReflected: false);
}

/// CRC-32 variant used in iSCSI, SSE4.2, ext4.
class Crc32Iscsi extends ParametricCrc {
  Crc32Iscsi() : super(32, 0x1EDC6F41, 0xFFFFFFFF, 0xFFFFFFFF);
}

/// CRC-24 variant used in OpenPGP, RTCM.
class Crc24OpenPgp extends ParametricCrc {
  Crc24OpenPgp()
      : super(24, 0x864CFB, 0xB704CE, 0,
            inputReflected: false, outputReflected: false);
}

/// CRC-16 variant used in X25.
class Crc16X25 extends ParametricCrc {
  Crc16X25() : super(16, 0x1021, 0xFFFF, 0xFFFF);
}

/// CRC-16 variant used in USB.
class Crc16Usb extends ParametricCrc {
  Crc16Usb() : super(16, 0x8005, 0xFFFF, 0xFFFF);
}

/// CRC-8 variant used in WCDMA (UMTS).
class Crc8Wcdma extends ParametricCrc {
  Crc8Wcdma() : super(8, 0x9B, 0, 0);
}

/// CRC-8 variant used in ATM Header Error Control sequence.
class Crc8Atm extends ParametricCrc {
  Crc8Atm()
      : super(8, 0x07, 0, 0x55, inputReflected: false, outputReflected: false);
}

/// CRC-8 variant used in Robust Header Compression (RFC3095).
class Crc8Rohc extends ParametricCrc {
  Crc8Rohc() : super(8, 0x07, 0xFF, 0);
}
