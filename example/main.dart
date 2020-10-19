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

/// Sample Dart 2+ code to use `crclib`.

import 'dart:convert';

import 'package:crclib/crclib.dart';
import 'package:crclib/catalog.dart';

void main() {
  assert(
      // ignore: unrelated_type_equality_checks
      Crc32Xz().convert(utf8.encode('123456789')) == 0xCBF43926,
      'Failed');
  assert(
      Crc32Xz().convert(utf8.encode('123456789')) == CrcValue(0xCBF43926),
      'Failed');
}
