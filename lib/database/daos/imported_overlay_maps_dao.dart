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

/// DAO for managing imported KMZ overlay map metadata
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

  Future<int> deleteMapById(String id) {
    return (delete(importedOverlayMaps)..where((t) => t.id.equals(id))).go();
  }
}
