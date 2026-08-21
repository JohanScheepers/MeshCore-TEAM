// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0
// http://creativecommons.org/licenses/by-nc-sa/4.0/
//
// This file is part of TEAM-Flutter.
// Non-commercial use only. See LICENSE file for details.

import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'mbtiles_registry.dart';
import 'mbtiles_source.dart';

/// Result of a successful MBTiles import.
class MbtilesImportResult {
  const MbtilesImportResult({
    required this.mapId,
    required this.name,
    required this.dirPath,
    required this.tileCount,
    required this.minZoom,
    required this.maxZoom,
    required this.sizeBytes,
    required this.boundsNorth,
    required this.boundsSouth,
    required this.boundsEast,
    required this.boundsWest,
  });

  final String mapId; // UUID used as folder name
  final String name;
  final String dirPath;
  final int tileCount;
  final int minZoom;
  final int maxZoom;
  final int sizeBytes;
  final double boundsNorth;
  final double boundsSouth;
  final double boundsEast;
  final double boundsWest;
}

/// Imports an MBTiles archive into the app's imported-maps directory.
///
/// Unlike [KmzImportService] there is nothing to unpack: an MBTiles file is
/// already a tile pyramid, so importing is a copy plus a metadata read. The
/// copy is still required because `file_picker` hands back a path in a cache
/// directory the OS may reclaim at any time.
class MbtilesImportService {
  /// Copies [sourceFile] into `{appDocuments}/imported_maps/{uuid}/` and reads
  /// its metadata.
  ///
  /// [onProgress] reports copied/total **bytes**, not tiles — these archives
  /// routinely run to hundreds of megabytes and the copy is the slow part.
  ///
  /// Throws [FormatException] with a user-presentable message if the file is
  /// not a usable raster MBTiles archive; the partial directory is cleaned up
  /// before rethrowing.
  Future<MbtilesImportResult> importMbtiles(
    File sourceFile, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (!sourceFile.existsSync()) {
      throw const FormatException('The selected file no longer exists.');
    }

    final mapId = _generateId();
    final docsDir = await getApplicationDocumentsDirectory();
    final dirPath = p.join(docsDir.path, 'imported_maps', mapId);
    await Directory(dirPath).create(recursive: true);

    try {
      final destPath = MbtilesRegistry.pathFor(dirPath);
      await _copyWithProgress(sourceFile, File(destPath), onProgress);

      // Open it to validate and pull metadata, then release the handle — the
      // registry opens its own when the map screen first renders the layer.
      final source = MbtilesSource.open(destPath);
      try {
        final fallbackName = p.basenameWithoutExtension(sourceFile.path);
        final name = source.name.toLowerCase().endsWith('.mbtiles')
            ? fallbackName
            : source.name;

        return MbtilesImportResult(
          mapId: mapId,
          name: name.trim().isEmpty ? fallbackName : name.trim(),
          dirPath: dirPath,
          tileCount: source.tileCount,
          minZoom: source.minZoom,
          maxZoom: source.maxZoom,
          sizeBytes: await File(destPath).length(),
          boundsNorth: source.bounds.north,
          boundsSouth: source.bounds.south,
          boundsEast: source.bounds.east,
          boundsWest: source.bounds.west,
        );
      } finally {
        source.close();
      }
    } catch (_) {
      // Never leave a half-copied archive behind; mirrors KmzImportService.
      try {
        final dir = Directory(dirPath);
        if (dir.existsSync()) await dir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  /// Streams [from] to [to], reporting byte progress.
  ///
  /// Deliberately not `File.copy`, which gives no progress, and not
  /// `readAsBytes`, which would hold the whole archive in memory.
  Future<void> _copyWithProgress(
    File from,
    File to,
    void Function(int done, int total)? onProgress,
  ) async {
    final total = await from.length();
    var done = 0;
    var lastReported = 0;

    final sink = to.openWrite();
    try {
      await for (final chunk in from.openRead()) {
        sink.add(chunk);
        done += chunk.length;
        // Throttle to whole percent to avoid thrashing setState on a big file.
        final percentStep = math.max(total ~/ 100, 1 << 20);
        if (done - lastReported >= percentStep || done == total) {
          lastReported = done;
          onProgress?.call(done, total);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  String _generateId() {
    final rand = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${bytes.sublist(0, 4).map(hex).join()}'
        '-${bytes.sublist(4, 6).map(hex).join()}'
        '-${bytes.sublist(6, 8).map(hex).join()}'
        '-${bytes.sublist(8, 10).map(hex).join()}'
        '-${bytes.sublist(10).map(hex).join()}';
  }
}
