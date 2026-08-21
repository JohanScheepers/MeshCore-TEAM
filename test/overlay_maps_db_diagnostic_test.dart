// Diagnostic: verifies that an MBTiles row round-trips through the drift
// schema with its layer_type intact, and that the v8 -> v9 migration adds the
// new columns without disturbing existing KMZ rows.
//
// Needs a native sqlite3 for the test runner (the app gets one from
// sqlite3_flutter_libs, which does not apply here):
//
//   flutter test test/overlay_maps_db_diagnostic_test.dart \
//     --dart-define=MBTILES_SQLITE_DLL=C:\Python314\DLLs\sqlite3.dll

import 'dart:ffi';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_team/database/database.dart';
import 'package:meshcore_team/database/daos/imported_overlay_maps_dao.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

const _dllPath = String.fromEnvironment('MBTILES_SQLITE_DLL');

void main() {
  if (_dllPath.isEmpty) {
    test('overlay maps db diagnostic (skipped: no DLL configured)', () {},
        skip: 'Pass --dart-define=MBTILES_SQLITE_DLL');
    return;
  }

  setUpAll(() {
    open.overrideFor(
        OperatingSystem.windows, () => DynamicLibrary.open(_dllPath));
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open(_dllPath));
  });

  test('an mbtiles row keeps its layerType and reads back as tiled', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.importedOverlayMapsDao.insertMap(
      ImportedOverlayMapsCompanion.insert(
        id: 'map-1',
        name: 'Test MBTiles',
        dirPath: '/tmp/imported_maps/map-1',
        tileCount: 136,
        importedAt: DateTime.now().millisecondsSinceEpoch,
        boundsNorth: 47.68,
        boundsSouth: 47.55,
        boundsEast: -122.24,
        boundsWest: -122.44,
        layerType: const Value('mbtiles'),
        minZoom: const Value(11),
        maxZoom: const Value(14),
        sizeBytes: const Value(131072),
      ),
    );

    final row = await db.importedOverlayMapsDao.getMapById('map-1');
    expect(row, isNotNull);

    // ignore: avoid_print
    print('layerType=${row!.layerType} minZoom=${row.minZoom} '
        'maxZoom=${row.maxZoom} opacity=${row.opacity} '
        'sizeBytes=${row.sizeBytes} isVisible=${row.isVisible}');

    expect(row.layerType, 'mbtiles',
        reason: 'layer_type did not survive the insert');
    expect(row.type, OverlayLayerType.mbtiles);
    expect(row.type.isTiled, isTrue,
        reason: 'the map screen skips any row whose type is not tiled');
    expect(row.isVisible, isTrue, reason: 'a fresh import must default visible');
    expect(row.opacity, 1.0, reason: 'opacity 0 would render nothing');
    expect(row.minZoom, 11);
    expect(row.maxZoom, 14);
  });

  test('a row inserted without a layerType defaults to kmz', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.importedOverlayMapsDao.insertMap(
      ImportedOverlayMapsCompanion.insert(
        id: 'map-2',
        name: 'Legacy KMZ',
        dirPath: '/tmp/imported_maps/map-2',
        tileCount: 4,
        importedAt: DateTime.now().millisecondsSinceEpoch,
        boundsNorth: 1,
        boundsSouth: 0,
        boundsEast: 1,
        boundsWest: 0,
      ),
    );

    final row = await db.importedOverlayMapsDao.getMapById('map-2');
    expect(row!.layerType, 'kmz');
    expect(row.type.isTiled, isFalse);
    expect(row.opacity, 1.0);
  });

  test('v8 -> v9 migration adds the columns and preserves KMZ rows', () async {
    // Build a v8-shaped imported_overlay_maps table by hand, matching the
    // schema as it existed before the MBTiles work.
    final raw = sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE imported_overlay_maps (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        dir_path TEXT NOT NULL,
        tile_count INTEGER NOT NULL,
        imported_at INTEGER NOT NULL,
        is_visible INTEGER NOT NULL DEFAULT 1,
        bounds_north REAL NOT NULL,
        bounds_south REAL NOT NULL,
        bounds_east REAL NOT NULL,
        bounds_west REAL NOT NULL,
        PRIMARY KEY (id)
      )
    ''');
    raw.execute(
      "INSERT INTO imported_overlay_maps VALUES "
      "('old-kmz', 'Pre-existing KMZ', '/tmp/old', 12, 1700000000000, 1, "
      "48.0, 47.0, -122.0, -123.0)",
    );

    // Apply the same ALTER statements the v9 migration issues.
    for (final sql in [
      "ALTER TABLE imported_overlay_maps ADD COLUMN layer_type TEXT NOT NULL DEFAULT 'kmz'",
      'ALTER TABLE imported_overlay_maps ADD COLUMN min_zoom INTEGER',
      'ALTER TABLE imported_overlay_maps ADD COLUMN max_zoom INTEGER',
      'ALTER TABLE imported_overlay_maps ADD COLUMN opacity REAL NOT NULL DEFAULT 1.0',
      'ALTER TABLE imported_overlay_maps ADD COLUMN size_bytes INTEGER NOT NULL DEFAULT 0',
    ]) {
      raw.execute(sql);
    }

    final row = raw
        .select('SELECT * FROM imported_overlay_maps WHERE id = ?', ['old-kmz'])
        .first;

    // ignore: avoid_print
    print('migrated row: layer_type=${row['layer_type']} '
        'opacity=${row['opacity']} size_bytes=${row['size_bytes']} '
        'min_zoom=${row['min_zoom']}');

    expect(row['name'], 'Pre-existing KMZ');
    expect(row['layer_type'], 'kmz');
    expect(row['opacity'], 1.0);
    expect(row['size_bytes'], 0);
    expect(row['min_zoom'], isNull);
    expect(row['is_visible'], 1);

    raw.dispose();
  });
}
