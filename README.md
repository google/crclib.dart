Dart crclib
===========

*This is not an official Google product.*

Generic CRC calculations as Dart converters and some common algorithms.

## To calculate the CRC value of any message

The easiest way to use this library is to call `convert` on the instance of
the desired CRC routine.

```dart
  Crc32Xz().convert(utf8.encode('123456789')) == 0xCBF43926
```

Another supported use case is as stream transformers.

```dart
  File(...).openRead().transform(Crc32Xz()).single.then(...)
```

Instead of using predefined classes, it is also possible to construct a
customized CRC function with `ParametricCrc` class. For a list of known
CRC routines, check out https://reveng.sourceforge.io/crc-catalogue/all.htm.

TODO:

  1. `inputReflected` and `outputReflected` can be different, see CRC-12/UMTS.
  2. Bit-level checksums (including non-multiple-of-8 checksums).

## To flip bits to obtain desired CRC values

With `CrcFlipper`, one can call `flipWithData` or `flipWithValue` depending on
whether they have access to the message, or only its calculated CRC value. The
snippet below is taken from [test/flipper_test.dart](test/flipper_test.dart).

```dart
      var inputMessage =
          'flipping lowercases to uppercases like mama pig making hot pancakes '
          'for daddy pig in peppa pig cartoon';
      // Mark the lower/upper-case bit in each character.
      // 0x61 = 'a' = 0110 0001
      //                | <-- 5th bit, zero-indexed
      // 0x41 = 'A' = 0100 0001
      var positions = inputMessage.codeUnits
          .asMap()
          .entries
          .where((e) => e.value >= 0x61 && e.value < 0x61 + 26)
          .map((e) => e.key * 8 + 5)
          .toSet();
      var flipper = CrcFlipper(Crc64());
      var solution = flipper.flipWithData(inputMessage.codeUnits, positions,
          CrcValue(BigInt.parse('DEADBEEFCAFEBABE', radix: 16)))!;
      var tmp = List.of(inputMessage.codeUnits, growable: false);
      solution.forEach((bitPosition) {
        var mask = 1 << (bitPosition % 8);
        tmp[bitPosition ~/ 8] ^= mask;
      });
      var outputMessage = String.fromCharCodes(tmp);
      expect(
          outputMessage,
          'flIPpiNG LOWErcAsEs To uPpERcaseS LIkE mAmA Pig mAKInG hOT paNcAKEs '
          'For DAdDY pig in peppa pig cartoon');
```

The detailed algorithm is documented in
[flipping_algorithm.md](flipping_algorithm.md).
