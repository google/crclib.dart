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
///   Crc32Xz().convert(utf8.encode('123456789')) == 0xCBF43926
///
/// Another supported use case is as stream transformers.
///
///   File(...).openRead().transform(Crc32Xz())
///
/// Instead of using predefined classes, it is also possible to construct a
/// customized CRC function with [ParametricCrc] class. For a list of known
/// CRC routines, check out http://reveng.sourceforge.net/crc-catalogue/all.htm.
///
/// TODO:
///   1. inputReflected and outputReflected can be different, see CRC-12/UMTS.
///   2. Bit-level checksums (including non-multiple-of-8 checksums).

export 'package:crclib/src/flipper.dart' show CrcFlipper;
export 'package:crclib/src/model.dart' show MultiCrc, ParametricCrc;
export 'package:crclib/src/primitive.dart' show CrcValue;
