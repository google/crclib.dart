// Generated by gen_reveng.dart.
//
// Copyright 2020 Google LLC.
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

import 'package:dart2_constant/convert.dart';
import 'package:test/test.dart';

import 'package:crclib/reveng.dart';

void main() {
  final input = utf8.encode('123456789');
  test('Crc8Autosar', () {
    expect(Crc8Autosar().convert(input), 0xdf);
  });
  test('Crc8Bluetooth', () {
    expect(Crc8Bluetooth().convert(input), 0x26);
  });
  test('Crc8Cdma2000', () {
    expect(Crc8Cdma2000().convert(input), 0xda);
  });
  test('Crc8Darc', () {
    expect(Crc8Darc().convert(input), 0x15);
  });
  test('Crc8DvbS2', () {
    expect(Crc8DvbS2().convert(input), 0xbc);
  });
  test('Crc8GsmA', () {
    expect(Crc8GsmA().convert(input), 0x37);
  });
  test('Crc8GsmB', () {
    expect(Crc8GsmB().convert(input), 0x94);
  });
  test('Crc8I4321', () {
    expect(Crc8I4321().convert(input), 0xa1);
    expect(Crc8Itu().convert(input), 0xa1);
  });
  test('Crc8ICode', () {
    expect(Crc8ICode().convert(input), 0x7e);
  });
  test('Crc8Lte', () {
    expect(Crc8Lte().convert(input), 0xea);
  });
  test('Crc8MaximDow', () {
    expect(Crc8MaximDow().convert(input), 0xa1);
    expect(Crc8Maxim().convert(input), 0xa1);
    expect(Crc8Dow().convert(input), 0xa1);
  });
  test('Crc8MifareMad', () {
    expect(Crc8MifareMad().convert(input), 0x99);
  });
  test('Crc8Nrsc5', () {
    expect(Crc8Nrsc5().convert(input), 0xf7);
  });
  test('Crc8OpenSafety', () {
    expect(Crc8OpenSafety().convert(input), 0x3e);
  });
  test('Crc8Rohc', () {
    expect(Crc8Rohc().convert(input), 0xd0);
  });
  test('Crc8SaeJ1850', () {
    expect(Crc8SaeJ1850().convert(input), 0x4b);
  });
  test('Crc8SMBus', () {
    expect(Crc8SMBus().convert(input), 0xf4);
    expect(Crc8().convert(input), 0xf4);
  });
  test('Crc8Tech3250', () {
    expect(Crc8Tech3250().convert(input), 0x97);
    expect(Crc8Aes().convert(input), 0x97);
    expect(Crc8Ebu().convert(input), 0x97);
  });
  test('Crc8Wcdma', () {
    expect(Crc8Wcdma().convert(input), 0x25);
  });
  test('Crc16Arc', () {
    expect(Crc16Arc().convert(input), 0xbb3d);
    expect(Crc16().convert(input), 0xbb3d);
    expect(Crc16Lha().convert(input), 0xbb3d);
    expect(Crc16Ibm().convert(input), 0xbb3d);
  });
  test('Crc16Cdma2000', () {
    expect(Crc16Cdma2000().convert(input), 0x4c06);
  });
  test('Crc16Cms', () {
    expect(Crc16Cms().convert(input), 0xaee7);
  });
  test('Crc16Dds110', () {
    expect(Crc16Dds110().convert(input), 0x9ecf);
  });
  test('Crc16DectR', () {
    expect(Crc16DectR().convert(input), 0x7e);
    expect(Crc16R().convert(input), 0x7e);
  });
  test('Crc16DectX', () {
    expect(Crc16DectX().convert(input), 0x7f);
    expect(Crc16X().convert(input), 0x7f);
  });
  test('Crc16Dnp', () {
    expect(Crc16Dnp().convert(input), 0xea82);
  });
  test('Crc16En13757', () {
    expect(Crc16En13757().convert(input), 0xc2b7);
  });
  test('Crc16GeniBus', () {
    expect(Crc16GeniBus().convert(input), 0xd64e);
    expect(Crc16Darc().convert(input), 0xd64e);
    expect(Crc16Epc().convert(input), 0xd64e);
    expect(Crc16EpcC1g2().convert(input), 0xd64e);
    expect(Crc16ICode().convert(input), 0xd64e);
  });
  test('Crc16Gsm', () {
    expect(Crc16Gsm().convert(input), 0xce3c);
  });
  test('Crc16Ibm3740', () {
    expect(Crc16Ibm3740().convert(input), 0x29b1);
    expect(Crc16Autosar().convert(input), 0x29b1);
    expect(Crc16CcittFalse().convert(input), 0x29b1);
  });
  test('Crc16IbmSdlc', () {
    expect(Crc16IbmSdlc().convert(input), 0x906e);
    expect(Crc16IsoHdlc().convert(input), 0x906e);
    expect(Crc16IsoIec144433B().convert(input), 0x906e);
    expect(Crc16X25().convert(input), 0x906e);
    expect(Crc16B().convert(input), 0x906e);
  });
  test('Crc16IsoIec144433A', () {
    expect(Crc16IsoIec144433A().convert(input), 0xbf05);
    expect(Crc16A().convert(input), 0xbf05);
  });
  test('Crc16Kermit', () {
    expect(Crc16Kermit().convert(input), 0x2189);
    expect(Crc16Ccitt().convert(input), 0x2189);
    expect(Crc16CcittTrue().convert(input), 0x2189);
    expect(Crc16V41Lsb().convert(input), 0x2189);
  });
  test('Crc16LJ1200', () {
    expect(Crc16LJ1200().convert(input), 0xbdf4);
  });
  test('Crc16MaximDow', () {
    expect(Crc16MaximDow().convert(input), 0x44c2);
    expect(Crc16Maxim().convert(input), 0x44c2);
  });
  test('Crc16Mcrf4xx', () {
    expect(Crc16Mcrf4xx().convert(input), 0x6f91);
  });
  test('Crc16Modbus', () {
    expect(Crc16Modbus().convert(input), 0x4b37);
  });
  test('Crc16Nrsc5', () {
    expect(Crc16Nrsc5().convert(input), 0xa066);
  });
  test('Crc16OpenSafetyA', () {
    expect(Crc16OpenSafetyA().convert(input), 0x5d38);
  });
  test('Crc16OpenSafetyB', () {
    expect(Crc16OpenSafetyB().convert(input), 0x20fe);
  });
  test('Crc16Profibus', () {
    expect(Crc16Profibus().convert(input), 0xa819);
    expect(Crc16Iec611582().convert(input), 0xa819);
  });
  test('Crc16Riello', () {
    expect(Crc16Riello().convert(input), 0x63d0);
  });
  test('Crc16SpiFujitsu', () {
    expect(Crc16SpiFujitsu().convert(input), 0xe5cc);
    expect(Crc16AugCcitt().convert(input), 0xe5cc);
  });
  test('Crc16T10Dif', () {
    expect(Crc16T10Dif().convert(input), 0xd0db);
  });
  test('Crc16Teledisk', () {
    expect(Crc16Teledisk().convert(input), 0xfb3);
  });
  test('Crc16Tms37157', () {
    expect(Crc16Tms37157().convert(input), 0x26b1);
  });
  test('Crc16Umts', () {
    expect(Crc16Umts().convert(input), 0xfee8);
    expect(Crc16Buypass().convert(input), 0xfee8);
    expect(Crc16Verifone().convert(input), 0xfee8);
  });
  test('Crc16Usb', () {
    expect(Crc16Usb().convert(input), 0xb4c8);
  });
  test('Crc16Xmodem', () {
    expect(Crc16Xmodem().convert(input), 0x31c3);
    expect(Crc16Acorn().convert(input), 0x31c3);
    expect(Crc16Lte().convert(input), 0x31c3);
    expect(Crc16V41Msb().convert(input), 0x31c3);
    expect(Crc16Zmodem().convert(input), 0x31c3);
  });
  test('Crc24Ble', () {
    expect(Crc24Ble().convert(input), 0xc25a56);
  });
  test('Crc24FlexRayA', () {
    expect(Crc24FlexRayA().convert(input), 0x7979bd);
  });
  test('Crc24FlexRayB', () {
    expect(Crc24FlexRayB().convert(input), 0x1f23b8);
  });
  test('Crc24Interlaken', () {
    expect(Crc24Interlaken().convert(input), 0xb4f3e6);
  });
  test('Crc24LteA', () {
    expect(Crc24LteA().convert(input), 0xcde703);
  });
  test('Crc24LteB', () {
    expect(Crc24LteB().convert(input), 0x23ef52);
  });
  test('Crc24OpenPgp', () {
    expect(Crc24OpenPgp().convert(input), 0x21cf02);
    expect(Crc24().convert(input), 0x21cf02);
  });
  test('Crc24Os9', () {
    expect(Crc24Os9().convert(input), 0x200fa5);
  });
  test('Crc32Aixm', () {
    expect(Crc32Aixm().convert(input), 0x3010bf7f);
    expect(Crc32Q().convert(input), 0x3010bf7f);
  });
  test('Crc32Autosar', () {
    expect(Crc32Autosar().convert(input), 0x1697d06a);
  });
  test('Crc32Base91D', () {
    expect(Crc32Base91D().convert(input), 0x87315576);
    expect(Crc32D().convert(input), 0x87315576);
  });
  test('Crc32Bzip2', () {
    expect(Crc32Bzip2().convert(input), 0xfc891918);
    expect(Crc32Aal5().convert(input), 0xfc891918);
    expect(Crc32DectB().convert(input), 0xfc891918);
    expect(Crc32B().convert(input), 0xfc891918);
  });
  test('Crc32CDRomEdc', () {
    expect(Crc32CDRomEdc().convert(input), 0x6ec2edc4);
  });
  test('Crc32Cksum', () {
    expect(Crc32Cksum().convert(input), 0x765e7680);
    expect(Crc32Posix().convert(input), 0x765e7680);
  });
  test('Crc32Iscsi', () {
    expect(Crc32Iscsi().convert(input), 0xe3069283);
    expect(Crc32Base91C().convert(input), 0xe3069283);
    expect(Crc32Castagnoli().convert(input), 0xe3069283);
    expect(Crc32Interlaken().convert(input), 0xe3069283);
    expect(Crc32C().convert(input), 0xe3069283);
  });
  test('Crc32IsoHdlc', () {
    expect(Crc32IsoHdlc().convert(input), 0xcbf43926);
    expect(Crc32().convert(input), 0xcbf43926);
    expect(Crc32Adccp().convert(input), 0xcbf43926);
    expect(Crc32V42().convert(input), 0xcbf43926);
    expect(Crc32Xz().convert(input), 0xcbf43926);
    expect(Crc32Pkzip().convert(input), 0xcbf43926);
  });
  test('Crc32JamCrc', () {
    expect(Crc32JamCrc().convert(input), 0x340bc6d9);
  });
  test('Crc32Mpeg2', () {
    expect(Crc32Mpeg2().convert(input), 0x376e6e7);
  });
  test('Crc32Xfer', () {
    expect(Crc32Xfer().convert(input), 0xbd0be338);
  });
  test('Crc40Gsm', () {
    expect(Crc40Gsm().convert(input), 0xd4164fc646);
  });
  test('Crc64Ecma182', () {
    expect(Crc64Ecma182().convert(input), 0x6c40df5f0b497347);
    expect(Crc64().convert(input), 0x6c40df5f0b497347);
  });
  test('Crc64GoIso', () {
    expect(Crc64GoIso().convert(input), 0xb90956c775a41001);
  });
  test('Crc64WE', () {
    expect(Crc64WE().convert(input), 0x62ec59e3f1a4f00a);
  });
  test('Crc64Xz', () {
    expect(Crc64Xz().convert(input), 0x995dc9bbdf1939fa);
    expect(Crc64GoEcma().convert(input), 0x995dc9bbdf1939fa);
  });
}