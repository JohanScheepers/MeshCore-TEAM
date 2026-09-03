// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0
//
// Unit tests for the coordinate math behind MBTiles rendering. These are the
// parts most likely to be silently wrong: an inverted row or a bad Mercator
// inverse produces a map that renders but sits in the wrong place.
//
// Opening an actual MBTiles file is deliberately not covered here — that needs
// the native sqlite3 library, which `sqlite3_flutter_libs` supplies to the app
// bundle but not to the test runner. See the manual verification steps.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_team/services/mbtiles_source.dart';

/// Forward Web Mercator, mirroring `MapTileCacheService._lonToTileX`.
int lonToTileX(double lon, int zoom) {
  final n = 1 << zoom;
  return ((lon + 180.0) / 360.0 * n).floor().clamp(0, n - 1);
}

/// Forward Web Mercator, mirroring `MapTileCacheService._latToTileY`.
int latToTileY(double lat, int zoom) {
  final n = 1 << zoom;
  final rad = lat * math.pi / 180.0;
  return ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n)
      .floor()
      .clamp(0, n - 1);
}

void main() {
  group('xyzToTmsRow', () {
    test('flips the row within the zoom level', () {
      // At z=1 there are 2 rows: XYZ 0 (north) <-> TMS 1, XYZ 1 <-> TMS 0.
      expect(MbtilesSource.xyzToTmsRow(0, 1), 1);
      expect(MbtilesSource.xyzToTmsRow(1, 1), 0);

      // At z=4 there are 16 rows.
      expect(MbtilesSource.xyzToTmsRow(0, 4), 15);
      expect(MbtilesSource.xyzToTmsRow(15, 4), 0);
      expect(MbtilesSource.xyzToTmsRow(6, 4), 9);
    });

    test('is its own inverse', () {
      for (final z in [0, 1, 5, 10, 16]) {
        final maxIndex = (1 << z) - 1;
        for (final y in [0, maxIndex ~/ 3, maxIndex]) {
          expect(
            MbtilesSource.xyzToTmsRow(MbtilesSource.xyzToTmsRow(y, z), z),
            y,
            reason: 'round trip failed for z=$z y=$y',
          );
        }
      }
    });

    test('z=0 has a single tile that maps to itself', () {
      expect(MbtilesSource.xyzToTmsRow(0, 0), 0);
    });
  });

  group('tileXToLon', () {
    test('maps the tile grid onto the full longitude range', () {
      expect(MbtilesSource.tileXToLon(0, 0), -180.0);
      expect(MbtilesSource.tileXToLon(1, 0), 180.0);
      expect(MbtilesSource.tileXToLon(1, 1), closeTo(0.0, 1e-9));
      expect(MbtilesSource.tileXToLon(1, 2), closeTo(-90.0, 1e-9));
    });

    test('inverts the forward projection to the tile west edge', () {
      for (final z in [1, 5, 12]) {
        for (final lon in [-179.9, -73.5, 0.0, 24.25, 179.9]) {
          final x = lonToTileX(lon, z);
          final west = MbtilesSource.tileXToLon(x, z);
          final east = MbtilesSource.tileXToLon(x + 1, z);
          expect(west, lessThanOrEqualTo(lon),
              reason: 'z=$z lon=$lon fell west of its tile');
          expect(east, greaterThan(lon),
              reason: 'z=$z lon=$lon fell east of its tile');
        }
      }
    });
  });

  group('tileYToLat', () {
    test('maps row 0 to the Mercator north limit', () {
      expect(MbtilesSource.tileYToLat(0, 0), closeTo(85.0511287798, 1e-6));
    });

    test('maps the grid midpoint to the equator', () {
      expect(MbtilesSource.tileYToLat(1, 1), closeTo(0.0, 1e-9));
      expect(MbtilesSource.tileYToLat(2, 2), closeTo(0.0, 1e-9));
    });

    test('is symmetric about the equator', () {
      expect(
        MbtilesSource.tileYToLat(0, 4),
        closeTo(-MbtilesSource.tileYToLat(16, 4), 1e-9),
      );
    });

    test('decreases monotonically as the row index grows', () {
      var previous = MbtilesSource.tileYToLat(0, 6);
      for (int y = 1; y <= 64; y++) {
        final lat = MbtilesSource.tileYToLat(y, 6);
        expect(lat, lessThan(previous), reason: 'row $y was not south of ${y - 1}');
        previous = lat;
      }
    });

    test('inverts the forward projection to the tile north edge', () {
      for (final z in [1, 5, 12]) {
        for (final lat in [-84.0, -33.9, 0.0, 47.6, 84.0]) {
          final y = latToTileY(lat, z);
          final north = MbtilesSource.tileYToLat(y, z);
          final south = MbtilesSource.tileYToLat(y + 1, z);
          expect(north, greaterThanOrEqualTo(lat),
              reason: 'z=$z lat=$lat fell north of its tile');
          expect(south, lessThan(lat),
              reason: 'z=$z lat=$lat fell south of its tile');
        }
      }
    });
  });

  group('round trip through TMS', () {
    test('a known Seattle tile survives XYZ -> TMS -> XYZ', () {
      // Seattle at z=12 is XYZ (656, 1430) in the standard slippy-map scheme.
      const z = 12;
      final x = lonToTileX(-122.3321, z);
      final y = latToTileY(47.6062, z);
      expect(x, 656);
      expect(y, 1430);

      final tmsRow = MbtilesSource.xyzToTmsRow(y, z);
      expect(tmsRow, 2665); // (2^12 - 1) - 1430
      expect(MbtilesSource.xyzToTmsRow(tmsRow, z), y);

      // And the tile's own bounds must contain the original point.
      expect(MbtilesSource.tileXToLon(x, z), lessThanOrEqualTo(-122.3321));
      expect(MbtilesSource.tileXToLon(x + 1, z), greaterThan(-122.3321));
      expect(MbtilesSource.tileYToLat(y, z), greaterThanOrEqualTo(47.6062));
      expect(MbtilesSource.tileYToLat(y + 1, z), lessThan(47.6062));
    });
  });
}
