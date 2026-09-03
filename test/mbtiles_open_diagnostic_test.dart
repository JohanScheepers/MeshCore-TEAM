// Diagnostic: exercises the real MbtilesSource.open() path against a real
// .mbtiles file, using a locally-available sqlite3 DLL.
//
// The app gets its native sqlite3 from `sqlite3_flutter_libs`, which only
// applies to the app bundle, so the test runner has to be pointed at a library
// itself. Set MBTILES_SQLITE_DLL and MBTILES_TEST_FILE to run this; the test
// skips itself otherwise so CI and other machines stay green.
//
//   flutter test test/mbtiles_open_diagnostic_test.dart \
//     --dart-define=MBTILES_SQLITE_DLL=C:\Python314\DLLs\sqlite3.dll \
//     --dart-define=MBTILES_TEST_FILE=C:\path\to\map.mbtiles

import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_team/services/mbtiles_source.dart';
import 'package:sqlite3/open.dart';

const _dllPath = String.fromEnvironment('MBTILES_SQLITE_DLL');
const _filePath = String.fromEnvironment('MBTILES_TEST_FILE');

void main() {
  if (_dllPath.isEmpty || _filePath.isEmpty) {
    test('mbtiles open diagnostic (skipped: no DLL/file configured)', () {},
        skip: 'Pass --dart-define=MBTILES_SQLITE_DLL and MBTILES_TEST_FILE');
    return;
  }

  setUpAll(() {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open(_dllPath),
    );
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open(_dllPath),
    );
  });

  test('opens a real mbtiles file and reads a tile', () {
    expect(File(_filePath).existsSync(), isTrue,
        reason: 'test file missing: $_filePath');

    final source = MbtilesSource.open(_filePath);
    addTearDown(source.close);

    // ignore: avoid_print
    print('name       : ${source.name}');
    // ignore: avoid_print
    print('format     : ${source.format}');
    // ignore: avoid_print
    print('zoom       : ${source.minZoom}..${source.maxZoom}');
    // ignore: avoid_print
    print('tileCount  : ${source.tileCount}');
    // ignore: avoid_print
    print('bounds     : N${source.bounds.north} S${source.bounds.south} '
        'E${source.bounds.east} W${source.bounds.west}');

    // ignore: avoid_print
    print('coverage   : ${source.describeCoverage()}');

    expect(source.tileCount, greaterThan(0));
    expect(source.maxZoom, greaterThanOrEqualTo(source.minZoom));
    expect(source.bounds.north, greaterThan(source.bounds.south));

    // Pull a tile from the middle of the declared extent at the coarsest zoom.
    final z = source.minZoom;
    final centreLon = (source.bounds.east + source.bounds.west) / 2;
    final centreLat = (source.bounds.north + source.bounds.south) / 2;
    final x = _lonToTileX(centreLon, z);
    final y = _latToTileY(centreLat, z);

    final bytes = source.tile(z, x, y);
    // ignore: avoid_print
    print('tile z$z/$x/$y -> ${bytes == null ? "NULL" : "${bytes.length} bytes"}');

    expect(bytes, isNotNull,
        reason: 'no tile at the centre of the declared bounds — '
            'the TMS row flip or the bounds are wrong');
    expect(bytes!.length, greaterThan(0));
  });
}

int _lonToTileX(double lon, int zoom) {
  final n = 1 << zoom;
  return ((lon + 180.0) / 360.0 * n).floor().clamp(0, n - 1);
}

int _latToTileY(double lat, int zoom) {
  final n = 1 << zoom;
  final rad = lat * math.pi / 180.0;
  return ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n)
      .floor()
      .clamp(0, n - 1);
}
