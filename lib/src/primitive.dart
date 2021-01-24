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

import 'dart:convert' show ByteConversionSinkBase;

import 'package:crclib/src/primitive_js.dart'
    if (dart.library.io) 'package:crclib/src/primitive_vm.dart'
    show maxBitwiseOperationLengthInBits;

/// Represents a CRC value. Objects of this class should only be tested for
/// equality against [int] or [BigInt], printed with [toString] or
/// [toRadixString], or up-valued [toBigInt].
class CrcValue {
  final int? _intValue;
  final BigInt? _bigIntValue;

  // BigInt values are ensured to be non-negative. But int values can go
  // negative due to the shifts and xors affecting the most-significant bit.
  CrcValue(dynamic value)
      : _intValue = (value is int) ? value : null,
        _bigIntValue = (value is BigInt) ? value : null {
    assert(_intValue != null || !_bigIntValue!.isNegative);
  }

  @override
  int get hashCode => (_intValue ?? _bigIntValue).hashCode;

  @override
  bool operator ==(Object other) {
    if (other is CrcValue) {
      return toBigInt() == other.toBigInt();
    } else if (other is int) {
      if (_intValue != null) {
        return _intValue == other;
      }
      return BigInt.from(other).toUnsigned(maxBitwiseOperationLengthInBits()) ==
          _bigIntValue;
    } else if (other is BigInt && !other.isNegative) {
      return toBigInt() == other;
    }
    return false;
  }

  @override
  String toString() => toRadixString(10);

  String toRadixString(int radix) => _intValue != null
      ? _intValue!.toRadixString(radix)
      : _bigIntValue!.toRadixString(radix);

  BigInt toBigInt() =>
      _bigIntValue ??
      BigInt.from(_intValue!).toUnsigned(maxBitwiseOperationLengthInBits());
}

/// Ultimate sink that stores the final CRC value.
class FinalSink extends Sink<CrcValue> {
  CrcValue? _value;

  CrcValue get value {
    return _value!;
  }

  @override
  void add(CrcValue data) {
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
/// [FinalSink].
abstract class CrcSink extends ByteConversionSinkBase {
  final int width;

  CrcSink(this.width);

  @override
  void add(List<int> input) => iterateBytes(input);

  /// Updates the internal of this sink with [input].
  void iterateBytes(Iterable<int> input);

  void addZeros(int bytes) => iterateBytes(Iterable.generate(bytes, (_) => 0));

  /// Copies the current state of the CRC calculation. The returned object will
  /// output to [outputSink], which should be a [FinalSink].
  CrcSink split(Sink<CrcValue> outputSink);
}

/// CRC calculation based on table lookup.
abstract class ParametricCrcSink<T> extends CrcSink {
  final List<T> table;
  final T finalMask;
  final Sink<CrcValue> _outputSink;
  late CrcLoopFunction _loopFunction;
  T value;
  bool _closed;

  ParametricCrcSink(
      int width, this.table, this.value, this.finalMask, this._outputSink)
      : _closed = false,
        assert(value is int || value is BigInt),
        super(width) {
    _loopFunction = selectLoopFunction();
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    iterateBytes(chunk.getRange(start, end));
    if (isLast) {
      close();
    }
  }

  @override
  void iterateBytes(Iterable<int> input) => _loopFunction(input);

  @override
  void addZeros(int bytes) {
    if (value == 0 || value == BigInt.zero) {
      return;
    }
    return super.addZeros(bytes);
  }

  @override
  void close() {
    if (!_closed) {
      _closed = true;
      if (value is int) {
        var v = (value as int) ^ (finalMask as int);
        _outputSink.add(CrcValue(v));
      } else {
        var v = (value as BigInt) ^ (finalMask as BigInt);
        _outputSink.add(CrcValue(v));
      }
      _outputSink.close();
    }
  }

  CrcLoopFunction selectLoopFunction();
}

typedef CrcLoopFunction = void Function(Iterable<int> chunk);

/// "Normal" CRC routines where the high bits are shifted out to the left.
///
/// The various [CrcLoopFunction] definitions are to optimize for different
/// integer sizes in Dart VM. See "Optimally shifting to the left" in
/// https://www.dartlang.org/articles/dart-vm/numeric-computation.
///
// Note for maintainers: Try not to call any function in these loops. Function
// calls require boxing and unboxing.
abstract class NormalSink<T> extends ParametricCrcSink<T> {
  NormalSink(
      List<T> table, T value, T finalMask, Sink<CrcValue> outputSink, int width)
      : super(width, table, value, finalMask, outputSink);
}

/// A normal sink backed by BigInt values.
class NormalSinkBigInt extends NormalSink<BigInt> {
  NormalSinkBigInt(List<BigInt> table, BigInt value, BigInt finalMask,
      Sink<CrcValue> outputSink, int width)
      : super(table, value, finalMask, outputSink, width);

  void _crcLoop(Iterable<int> chunk) {
    final shiftWidth = width - 8;
    final mask = (BigInt.one << shiftWidth) - BigInt.one;
    for (final b in chunk) {
      value = table[((value >> shiftWidth).toUnsigned(8).toInt() ^ b) & 0xFF] ^
          ((value & mask) << 8);
    }
  }

  @override
  CrcLoopFunction selectLoopFunction() {
    return _crcLoop;
  }

  @override
  NormalSinkBigInt split(Sink<CrcValue> outputSink) {
    return NormalSinkBigInt(table, value, finalMask, outputSink, width);
  }
}

/// Reflects the least [width] bits of input value [i].
///
/// For example: the value of `_reflect(0x80, 8)` is 0x01 because 0x80 is
/// 10000000 in binary; its reflected binary value is 00000001, which is 0x01 in
/// hexadecimal. And `_reflect(0x3e23, 3)` is 6 because the least significant 3
/// bits are 011, when reflected is 110, which is 6 in decimal.
int reflectInt(int i, int width) {
  var ret = 0;
  while (width-- > 0) {
    ret = (ret << 1) | (i & 1);
    i >>= 1;
  }
  return ret;
}

BigInt reflectBigInt(BigInt i, int width) {
  var ret = BigInt.zero;
  while (width-- > 0) {
    ret = (ret << 1) | (i.isOdd ? BigInt.one : BigInt.zero);
    i >>= 1;
  }
  return ret;
}

/// "Reflected" CRC routines.
///
/// The specialized loop functions are meant to speed up calculations
/// according to the width of the CRC value.
abstract class ReflectedSink<T> extends ParametricCrcSink<T> {
  ReflectedSink(int width, List<T> table, T reflectedValue, T finalMask,
      Sink<CrcValue> outputSink)
      : super(width, table, reflectedValue, finalMask, outputSink);
}

class ReflectedSinkBigInt extends ReflectedSink<BigInt> {
  ReflectedSinkBigInt(int width, List<BigInt> table, BigInt value,
      BigInt finalMask, Sink<CrcValue> outputSink)
      : super(width, table, reflectBigInt(value, width), finalMask, outputSink);

  void _crcLoop(Iterable<int> chunk) {
    for (final b in chunk) {
      value = table[(value.toUnsigned(8).toInt() ^ b) & 0xFF] ^ (value >> 8);
    }
  }

  @override
  CrcLoopFunction selectLoopFunction() {
    return _crcLoop;
  }

  @override
  ReflectedSinkBigInt split(Sink<CrcValue> outputSink) {
    return ReflectedSinkBigInt(
        width, table, reflectBigInt(value, width), finalMask, outputSink);
  }
}
