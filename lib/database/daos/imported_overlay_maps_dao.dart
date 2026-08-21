// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0
// http://creativecommons.org/licenses/by-nc-sa/4.0/
//
// This file is part of TEAM-Flutter.
// Non-commercial use only. See LICENSE file for details.

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'imported_overlay_maps_dao.g.dart';

/// The kind of data an imported overlay map holds.
///
/// Stored as a string in `imported_overlay_maps.layer_type` so that unknown
/// future values coming from a newer team-config export degrade to [kmz]
/// rather than throwing.
enum OverlayLayerType {
  /// Garmin-style KMZ: a flat list of lat/lon-boxed images, rendered through
  /// `OverlayImageLayer`.
  kmz('kmz'),

  /// An MBTiles SQLite database: a Web Mercator pyramid, rendered through
  /// a `TileLayer` with a custom tile provider.
  mbtiles('mbtiles'),

  /// A geospatial PDF that was rasterised and reprojected into an MBTiles
  /// file at import time. Renders identically to [mbtiles].
  geopdf('geopdf');

  const OverlayLayerType(this.dbValue);

  final String dbValue;

  static OverlayLayerType fromDb(String? value) {
    for (final type in OverlayLayerType.values) {
      if (type.dbValue == value) return type;
    }
    return OverlayLayerType.kmz;
  }

  /// True when this layer is backed by an `map.mbtiles` file on disk.
  bool get isTiled =>
      this == OverlayLayerType.mbtiles || this == OverlayLayerType.geopdf;
}

/// Convenience accessors for the string-typed discriminator column.
extension ImportedOverlayMapTypeX on ImportedOverlayMapData {
  OverlayLayerType get type => OverlayLayerType.fromDb(layerType);
}

/// DAO for managing imported overlay map metadata
@DriftAccessor(tables: [ImportedOverlayMaps])
class ImportedOverlayMapsDao extends DatabaseAccessor<AppDatabase>
    with _$ImportedOverlayMapsDaoMixin {
  ImportedOverlayMapsDao(super.db);

  Stream<List<ImportedOverlayMapData>> watchAllMaps() {
    return (select(importedOverlayMaps)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.importedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<ImportedOverlayMapData>> getAllMaps() {
    return (select(importedOverlayMaps)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.importedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<ImportedOverlayMapData?> getMapById(String id) {
    return (select(importedOverlayMaps)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertMap(ImportedOverlayMapsCompanion map) {
    return into(importedOverlayMaps).insert(map);
  }

  Future<void> updateVisibility(String id, bool isVisible) {
    return (update(importedOverlayMaps)..where((t) => t.id.equals(id))).write(
      ImportedOverlayMapsCompanion(isVisible: Value(isVisible)),
    );
  }

  Future<void> updateOpacity(String id, double opacity) {
    return (update(importedOverlayMaps)..where((t) => t.id.equals(id))).write(
      ImportedOverlayMapsCompanion(opacity: Value(opacity.clamp(0.0, 1.0))),
    );
  }

  Future<int> deleteMapById(String id) {
    return (delete(importedOverlayMaps)..where((t) => t.id.equals(id))).go();
  }
}
