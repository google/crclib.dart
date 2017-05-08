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

import 'package:benchmark_harness/benchmark_harness.dart';

import 'package:crclib/crclib.dart';

class CrcSink extends Sink<int> {
  int value;

  @override
  void add(int i) {
    value = i;
  }

  @override
  void close() {}
}

final dataBlock = new List<int>.filled(1024, 0xFF);

typedef ParametricCrc CrcConstructor();

class CrcBenchmark extends BenchmarkBase {
  final CrcConstructor _constructor;
  final int _size;

  const CrcBenchmark(this._constructor, this._size)
      : super('${_constructor().runtimeType}_${_size}');

  void run() {
    int sent = 0;
    final outputSink = new CrcSink();
    final inputSink = _constructor().startChunkedConversion(outputSink);
    while (sent < _size) {
      inputSink.add(dataBlock);
      sent += dataBlock.length;
    }
    inputSink.close();
  }
}

main() {
  final constructors = [
    () => new Crc32Bzip2(),
    () => new Crc32Zlib(),
  ];
  final sizes = [1 << 10, 1 << 11, 1 << 12, 1 << 23, 1 << 24, 1 << 25];

  for (final constructor in constructors) {
    for (final size in sizes) {
      new CrcBenchmark(constructor, size).report();
    }
  }
}
