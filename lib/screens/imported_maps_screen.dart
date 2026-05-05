// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0
// http://creativecommons.org/licenses/by-nc-sa/4.0/
//
// This file is part of TEAM-Flutter.
// Non-commercial use only. See LICENSE file for details.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:meshcore_team/database/database.dart';
import 'package:meshcore_team/services/kmz_import_service.dart';

class ImportedMapsScreen extends StatefulWidget {
  const ImportedMapsScreen({super.key});

  @override
  State<ImportedMapsScreen> createState() => _ImportedMapsScreenState();
}

class _ImportedMapsScreenState extends State<ImportedMapsScreen> {
  bool _isBusy = false;
  int _importDone = 0;
  int _importTotal = 0;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(2)} GB';
  }

  String _formatDate(int msSinceEpoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(msSinceEpoch);
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $hh:$mm';
  }

  String _boundsLabel(ImportedOverlayMapData m) {
    final n = m.boundsNorth.toStringAsFixed(4);
    final s = m.boundsSouth.toStringAsFixed(4);
    final e = m.boundsEast.toStringAsFixed(4);
    final w = m.boundsWest.toStringAsFixed(4);
    return 'N$n S$s E$e W$w';
  }

  /// Calculates the total size of files inside an extracted overlay directory.
  Future<int> _dirSizeBytes(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _importKmz() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['kmz'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isBusy = true);
    setState(() {
      _isBusy = true;
      _importDone = 0;
      _importTotal = 0;
    });
    try {
      final kmzService = KmzImportService();
      final importResult = await kmzService.importKmz(
        File(path),
        onProgress: (done, total) {
          if (mounted) setState(() { _importDone = done; _importTotal = total; });
        },
      );

      // Save the doc.kml manifest for later tile reloading
      await kmzService.saveManifest(importResult.dirPath, importResult.tiles);

      // Calculate total on-disk size
      final sizeBytes = await _dirSizeBytes(importResult.dirPath);

      final db = context.read<AppDatabase>();
      await db.importedOverlayMapsDao.insertMap(
        ImportedOverlayMapsCompanion.insert(
          id: const Uuid().v4(),
          name: importResult.name,
          dirPath: importResult.dirPath,
          tileCount: importResult.tiles.length,
          importedAt: DateTime.now().millisecondsSinceEpoch,
          boundsNorth: importResult.boundsNorth,
          boundsSouth: importResult.boundsSouth,
          boundsEast: importResult.boundsEast,
          boundsWest: importResult.boundsWest,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported "${importResult.name}" — ${importResult.tiles.length} tile${importResult.tiles.length == 1 ? '' : 's'} (${_formatBytes(sizeBytes)})',
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteMap(ImportedOverlayMapData m) async {
    final ok = await _confirm(
      'Delete map?',
      'This will remove "${m.name}" and its image files from the device.',
    );
    if (!ok) return;

    setState(() => _isBusy = true);
    try {
      final dir = Directory(m.dirPath);
      if (dir.existsSync()) await dir.delete(recursive: true);
      final db = context.read<AppDatabase>();
      await db.importedOverlayMapsDao.deleteMapById(m.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _toggleVisibility(ImportedOverlayMapData m) async {
    final db = context.read<AppDatabase>();
    await db.importedOverlayMapsDao.updateVisibility(m.id, !m.isVisible);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Imported Maps (KMZ)'),
        actions: [
          IconButton(
            tooltip: 'Import KMZ file',
            onPressed: _isBusy ? null : _importKmz,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<ImportedOverlayMapData>>(
        stream: db.importedOverlayMapsDao.watchAllMaps(),
        builder: (context, snapshot) {
          final maps = snapshot.data ?? const <ImportedOverlayMapData>[];

          if (maps.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No imported maps',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Import a Garmin-style KMZ file to display a '
                      'custom raster map as an overlay on top of the base map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _importKmz,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Import KMZ'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: maps.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final m = maps[index];
              final subtitle =
                  '${m.tileCount} tile${m.tileCount == 1 ? '' : 's'} • '
                  '${_boundsLabel(m)}\n'
                  'Imported ${_formatDate(m.importedAt)}';

              return ListTile(
                leading: Icon(
                  Icons.layers,
                  color: m.isVisible
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                title: Text(m.name),
                subtitle: Text(subtitle),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: m.isVisible ? 'Hide on map' : 'Show on map',
                      child: IconButton(
                        onPressed: _isBusy ? null : () => _toggleVisibility(m),
                        icon: Icon(
                          m.isVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Delete',
                      child: IconButton(
                        onPressed: _isBusy ? null : () => _deleteMap(m),
                        icon: const Icon(Icons.delete),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
          if (_isBusy)
            const ModalBarrier(color: Color(0x88000000), dismissible: false),
          if (_isBusy)
            Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Importing map…',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _importTotal > 0
                            ? _importDone / _importTotal
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _importTotal > 0
                            ? 'Extracting tile $_importDone of $_importTotal…'
                            : 'Reading archive…',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }
}
