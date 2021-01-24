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

import 'dart:collection' show ListMixin;
import 'dart:typed_data' show Uint32List;

import 'package:meta/meta.dart';

import 'package:crclib/crclib.dart' show CrcValue;
import 'package:crclib/src/model.dart' show BaseCrc;
import 'package:crclib/src/primitive.dart' show CrcSink, FinalSink;

abstract class _FixedList<T> extends ListMixin<T> {
  @override
  void add(T b) {
    throw UnsupportedError('Adding element is not supported');
  }

  @override
  set length(int newLength) {
    throw UnsupportedError('Resizing is not supported');
  }
}

/// A fixed-length container of bits.
///
/// This is a mutable, much simpler version of [BigInt]. Initially, all elements
/// are zeroed. This class is mainly used in [BitMatrix].
@visibleForTesting
class BitArray extends _FixedList<bool> {
  late Uint32List _vector;
  final int _bitCount;

  BitArray(this._bitCount) {
    if (_bitCount < 0) {
      throw ArgumentError('Bit count must not be negative');
    }
    _vector = Uint32List((_bitCount + 31) ~/ 32);
  }

  /// Zeros out the array.
  void reset() {
    for (var i = 0; i < _vector.length; ++i) {
      _vector[i] = 0;
    }
  }

  @override
  bool operator [](int index) {
    if (index < 0 || index >= _bitCount) {
      throw RangeError.value(index, 'index', 'is not in range [0, $_bitCount)');
    }
    var quadIndex = index ~/ 32;
    var bitIndex = index % 32;
    return _vector[quadIndex] & (1 << bitIndex) != 0;
  }

  @override
  void operator []=(int index, bool on) {
    if (index < 0 || index >= _bitCount) {
      throw RangeError.value(index, 'index', 'is not in range [0, $_bitCount)');
    }
    var quadIndex = index ~/ 32;
    var bitIndex = index % 32;
    var mask = 1 << bitIndex;
    if (on) {
      _vector[quadIndex] |= mask;
    } else {
      _vector[quadIndex] &= ~mask;
    }
  }

  @override
  int get length => _bitCount;

  @override
  String toString() => '[' + map((e) => e ? '1' : '0').join(',') + ']';
}

/// A fixed-size matrix of bits. All elements are initially zeroed.
@visibleForTesting
class BitMatrix extends _FixedList<BitArray> {
  final int _colCount;
  final int _rowCount;
  late List<BitArray> _rows;

  BitMatrix(this._rowCount, this._colCount) {
    if (_rowCount < 0 || _colCount < 0) {
      throw ArgumentError('Both row and column counts must not be negative');
    }
    _rows =
        List.generate(_rowCount, (_) => BitArray(_colCount), growable: false);
  }

  /// Sets all elements to zeros.
  void reset() => _rows.forEach((r) => r.reset());

  @override
  BitArray operator [](int index) {
    if (index < 0 || index >= _rowCount) {
      throw RangeError.value(index, 'index', 'is not in range [0, $_rowCount)');
    }
    return _rows[index];
  }

  @override
  int get length => _rowCount;

  void _swapRows(int i, int j) {
    assert(i >= 0 && i < _rowCount && j >= 0 && j < _rowCount);
    if (i == j) {
      return;
    }
    var t = _rows[i];
    _rows[i] = _rows[j];
    _rows[j] = t;
  }

  /// Performs Gaussian Elimination in-place.
  ///
  /// The matrix will be in *reduced* row echelon form after [eliminate]. The
  /// returned value is a list of pivot column indices corresponding to the
  /// rows, i.e. `ret[row] = col` means that the pivot on row `row` is at column
  /// `col`. If there is no pivots on a row, that row will have the value of -1.
  List<int> eliminate() {
    var ret = List.filled(_rowCount, -1, growable: false);
    var fixedRowsCount = 0;
    for (var col = 0; col < _colCount; ++col) {
      // Walk through each column.
      var row = fixedRowsCount;
      for (; row < _rowCount; ++row) {
        // Walk through all the not-fixed rows to find a pivot.
        if (_rows[row][col]) {
          break;
        }
      }
      if (row >= _rowCount) {
        // No pivot found in this column.
        continue;
      }

      // Found a pivot. Swap this row up. It becomes fixed.
      _swapRows(fixedRowsCount, row);
      ret[fixedRowsCount] = col;

      // Then eliminate pivots in other rows.
      for (row = 0; row < _rowCount; ++row) {
        if (row == fixedRowsCount) {
          continue;
        }
        // Walk through the rest of the rows.
        if (_rows[row][col]) {
          // This row has a pivot, eliminate it.
          for (var i = col; i < _colCount; ++i) {
            _rows[row][i] ^= _rows[fixedRowsCount][i];
          }
        }
      }
      ++fixedRowsCount;
    }
    return ret;
  }

  @override
  String toString() => map((r) => r.toString()).join(',\n');

  @override
  void operator []=(int index, BitArray value) {
    throw UnsupportedError(
        'Directly assigning rows to a BitMatrix is not supported');
  }
}

/// Returns an augmented matrix representing the linear system Ax = b.
///
/// Where:
///
/// *  `A` is a binary matrix and `A[r][c]` is the r-th bit (zero-indexed)
/// of the c-th element (zero-indexed) in [checksums].
/// *  `b` is the column vector from the bits of [target].
/// *  `x` is the column vector of [width] rows, representing the unknowns.
///
/// The returned augmented matrix is [A|b].
@visibleForTesting
BitMatrix generateAugmentedMatrix(
    int width, List<BigInt> checksums, BigInt target) {
  var matrix = BitMatrix(width, checksums.length + 1);
  // First horizontally stack the [checksums], each checksum is a column.
  for (var r = 0; r < width; r++) {
    var mask = BigInt.one << r;
    for (var c = 0; c < checksums.length; ++c) {
      var checksum = checksums[c];
      if ((checksum & mask) != BigInt.zero) {
        matrix[r][c] = true;
      }
    }
  }
  // Then augment the matrix with [target] as the last column.
  for (var i = 0; i < width; i++) {
    var mask = BigInt.one << i;
    matrix[i][checksums.length] = (mask & target) != BigInt.zero;
  }
  return matrix;
}

/// Returns a solution for the Ax = b system of equations.
///
/// The argument [matrix] is an augmented matrix [A|b], as returned by
/// [generateAugmentedMatrix].
///
/// If there is no solutions, `null` is returned. Otherwise, only one solution
/// is returned. All free variables are zeros.
@visibleForTesting
BitArray? solveAugmentedMatrix(BitMatrix matrix) {
  var pivotPositions = matrix.eliminate();
  var height = matrix.length;
  var width = matrix[0].length - 1; // Minus the augmented column.
  var selected = BitArray(width);
  // Back solving from the last row.
  for (var row = height - 1; row >= 0; --row) {
    var pivotIndex = pivotPositions[row];
    if (pivotIndex < 0) {
      // This row is full of zeros, the system is underdetermined.
      continue;
    }
    if (pivotIndex >= width) {
      // The pivot index is not in range, the system is inconsistent.
      return null;
    }
    var known = false;
    for (var col = pivotIndex + 1; col < width; ++col) {
      known ^= (selected[col] & matrix[row][col]);
    }
    selected[pivotIndex] = known ^ matrix[row][width];
  }
  return selected;
}

/// Utility class to find bit positions to flip to yield a desired CRC value.
class CrcFlipper {
  final BaseCrc _crcFunction;

  const CrcFlipper(this._crcFunction);

  /// Returns a list of bit positions to flip, or `null` if not possible.
  ///
  /// [data] is the input bytes. [allowedPositions] is a set of bit positions to
  /// be flipped, zero-indexed. The returned value will be a subset of
  /// [allowedPositions]. And [target] is the desired value after flipping.
  ///
  /// See [flipWithValue].
  Set<int>? flipWithData(
      List<int> data, Iterable<int> allowedPositions, CrcValue target) {
    return flipWithValue(
        _crcFunction.convert(data), data.length, allowedPositions, target);
  }

  /// Returns a list of bit positions to flip, or `null` if not possible.
  ///
  /// [value] is the original CRC value. [allowedPositions] is a set of bit
  /// positions to be flipped, zero-indexed. The returned value will be a subset
  /// of [allowedPositions]. And [target] is the desired value after flipping.
  ///
  /// Throws [ArgumentError] if any value in [allowedPositions] is negative or
  /// larger than 8 times [lengthInBytes].
  ///
  /// Throws [ArgumentError] if [target] does not have the same width as the CRC
  /// function provided to this instance.
  Set<int>? flipWithValue(CrcValue value, int lengthInBytes,
      Iterable<int> allowedPositions, CrcValue target) {
    if (allowedPositions.isEmpty) {
      return null;
    }
    if (value == target) {
      return Set<int>();
    }
    var lengthInBits = lengthInBytes * 8;
    if (allowedPositions.any((i) => i < 0 || i >= lengthInBits)) {
      throw ArgumentError.value(allowedPositions, 'allowedPositions',
          'contains at least one negative value or larger than $lengthInBits');
    }
    var positions = allowedPositions.toList(growable: false);
    positions.sort();
    var positionalChecksums =
        _calculatePositionalChecksums(lengthInBytes, positions);
    var matrix = generateAugmentedMatrix(_crcFunction.lengthInBits,
        positionalChecksums, value.toBigInt() ^ target.toBigInt());
    var selectedPositions = solveAugmentedMatrix(matrix);
    return selectedPositions
        ?.asMap()
        ?.entries
        ?.where((e) => e.value)
        ?.map((e) => positions[e.key])
        ?.toSet();
  }

  /// Returns a list of checksums corresponding to setting one bit a time.
  ///
  /// [lengthInBytes] is the length of the data. [positions] is the list of bit
  /// positions to be set one at a time. For each position, the checksum of an
  /// array of all zeros XOR with the checksum of that same array with the bit
  /// set will be returned.
  List<BigInt> _calculatePositionalChecksums(
      int lengthInBytes, List<int> positions) {
    if (positions.isEmpty) {
      return [];
    }

    final sorted = List.generate(positions.length, (i) => i);
    sorted.sort((a, b) => positions[a] - positions[b]);

    var bytesProcessed = 0;
    final blankSink = FinalSink();
    final blankCrc = _crcFunction.startChunkedConversion(blankSink);
    final ret = List<BigInt>.generate(sorted.length, (i) {
      final positionIndex = sorted[i];
      final bitPosition = positions[positionIndex];
      final positionInBytes = bitPosition ~/ 8;
      final deltaInBytes = positionInBytes - bytesProcessed;
      if (deltaInBytes > 0) {
        blankCrc.addZeros(deltaInBytes);
        bytesProcessed += deltaInBytes;
      }
      final singleBitChecksum = FinalSink();
      final singleBitCrc = blankCrc.split(singleBitChecksum);
      singleBitCrc.add([1 << (bitPosition % 8)]);
      final remainingZeros = lengthInBytes - bytesProcessed - 1;
      if (remainingZeros > 0) {
        singleBitCrc.addZeros(remainingZeros);
      }
      singleBitCrc.close();
      return singleBitChecksum.value.toBigInt();
    }, growable: false);
    if (bytesProcessed < lengthInBytes) {
      // The blank CRC needs more zeros.
      blankCrc.addZeros(lengthInBytes - bytesProcessed);
      bytesProcessed += lengthInBytes - bytesProcessed;
    }
    blankCrc.close();
    final blankValue = blankSink.value.toBigInt();
    for (var i = 0; i < ret.length; ++i) {
      ret[i] ^= blankValue;
    }
    return ret;
  }
}
