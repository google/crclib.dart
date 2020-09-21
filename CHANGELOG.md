#### 2.0.0 - 2020-09-20
  * **Breaking change:** Only support Dart 2+.
  * **Breaking change:** CRC result is now a `CrcValue`, not `int` so that we
      can support long CRC values (such as CRC-64) in JavaScript.
  * **Breaking change:** Predefined CRC classes are no longer in `crclib.dart`.
  * Support `dart2js` environment for CRCs longer than 32 bits.

#### 1.1.0 - 2020-08-23
  * Add CRC functions from reveng catalog.

#### 1.0.1 - 2018-09-21
  * Support both Dart 1 and Dart 2.

#### 1.0.0 - 2017-04-20
  * First release.
