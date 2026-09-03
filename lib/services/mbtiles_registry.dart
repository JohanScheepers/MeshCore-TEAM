// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0
// http://creativecommons.org/licenses/by-nc-sa/4.0/
//
// This file is part of TEAM-Flutter.
// Non-commercial use only. See LICENSE file for details.

import 'package:path/path.dart' as p;

import 'mbtiles_source.dart';

/// Owns the open [MbtilesSource] handles for imported tiled overlay maps.
///
/// This exists as a single app-wide instance rather than as state on the map
/// screen because two screens need the same handle: the map renders through
/// it, and the manage screen has to close it before deleting the file. On
/// Windows an open SQLite handle blocks `Directory.delete` outright.
///
/// Registered as a `Provider` in main.dart alongside `KmzImportService`.
class MbtilesRegistry {
  final Map<String, MbtilesSource> _sources = {};

  /// Canonical file name for the MBTiles archive inside an imported map's
  /// directory. Geospatial PDF imports converge on the same name so that both
  /// layer types render through one path.
  static const String fileName = 'map.mbtiles';

  /// Full path to the archive for a map stored in [dirPath].
  static String pathFor(String dirPath) => p.join(dirPath, fileName);

  /// The already-open handle for [id], or null if it has not been opened.
  MbtilesSource? get(String id) {
    final source = _sources[id];
    if (source != null && source.isClosed) {
      _sources.remove(id);
      return null;
    }
    return source;
  }

  /// Opens the archive for [id] if it is not already open.
  ///
  /// Returns null when the file is missing or unreadable — a corrupt or
  /// externally deleted map should make its layer disappear, not break the
  /// whole map screen.
  MbtilesSource? ensureOpen(String id, String dirPath) {
    final existing = get(id);
    if (existing != null) return existing;

    try {
      final source = MbtilesSource.open(pathFor(dirPath));
      _sources[id] = source;
      return source;
    } catch (e) {
      // ignore: avoid_print
      print('[MBTiles] failed to open map $id at $dirPath: $e');
      return null;
    }
  }

  /// Closes and forgets the handle for [id]. Safe to call when not open.
  void close(String id) {
    _sources.remove(id)?.close();
  }

  /// Closes every open handle. Called when the map screen is disposed.
  void closeAll() {
    for (final source in _sources.values) {
      source.close();
    }
    _sources.clear();
  }
}
