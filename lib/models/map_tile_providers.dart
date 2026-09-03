// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0
// http://creativecommons.org/licenses/by-nc-sa/4.0/
//
// This file is part of TEAM-Flutter.
// Non-commercial use only. See LICENSE file for details.

import 'package:meshcore_team/models/app_settings.dart';

class MapTileProviderOption {
  final String id;
  final String label;
  final String urlTemplate;
  final List<String> subdomains;

  /// Deepest zoom level this service actually serves tiles for.
  ///
  /// Verified by probing each service rather than taken from documentation —
  /// see the per-provider notes below. Requesting past this is not harmless:
  /// USGS returns 404, and OpenTopoMap returns HTTP 200 with a single blank
  /// placeholder PNG that the tile cache would happily store as a real tile.
  ///
  /// The camera is allowed to zoom past this ([kOverzoomLevels]); flutter_map
  /// upscales the deepest native tile instead of requesting one that does not
  /// exist.
  final int maxNativeZoom;

  const MapTileProviderOption({
    required this.id,
    required this.label,
    required this.urlTemplate,
    this.subdomains = const <String>[],
    this.maxNativeZoom = 18,
  });
}

/// How far the camera may zoom past a provider's deepest real tile.
///
/// Past this the base map is just a blurry upscale, but the extra headroom
/// matters for placing a waypoint precisely or separating overlapping markers.
const int kOverzoomLevels = 2;

/// Lowest zoom the camera may reach. Not provider-specific: every provider
/// here serves the whole world at low zoom.
const double kMapMinZoom = 3.0;

const List<MapTileProviderOption> kMapTileProviderOptions = [
  MapTileProviderOption(
    id: MapProvider.mapnik,
    label: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    // z19 serves; z20 returns HTTP 400.
    maxNativeZoom: 19,
  ),
  MapTileProviderOption(
    id: MapProvider.topo,
    label: 'OpenTopoMap',
    urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    // z18+ returns HTTP 200 with a blank placeholder — byte-identical across
    // unrelated locations and zooms — so it cannot be detected as an error.
    maxNativeZoom: 17,
  ),
  MapTileProviderOption(
    id: MapProvider.usgsSat,
    label: 'USGS Satellite',
    urlTemplate:
        'https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/tile/{z}/{y}/{x}',
    // z17+ returns 404. Matches the service's declared maxScale of 1:9027.98,
    // which is exactly the z16 scale.
    maxNativeZoom: 16,
  ),
  MapTileProviderOption(
    id: MapProvider.usgsTopo,
    label: 'USGS Topographic',
    urlTemplate:
        'https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/{z}/{y}/{x}',
    // Same 404-past-z16 behaviour and same declared maxScale as USGS Satellite.
    maxNativeZoom: 16,
  ),
  MapTileProviderOption(
    id: MapProvider.hot,
    label: 'Humanitarian',
    urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    // z19 returns 404 in both dense-coverage and sparse regions, so this is a
    // server zoom cap rather than missing local coverage.
    maxNativeZoom: 18,
  ),
  MapTileProviderOption(
    id: MapProvider.esriSat,
    label: 'ESRI Satellite',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    // Real imagery depth is region-dependent: z20 in metros (Denver, NYC),
    // but only z19 in rural areas (rural KS, Yosemite), where z20 already
    // returns a fixed grey "no data" placeholder with HTTP 200. Set to the
    // rural depth deliberately — this app is used in backcountry far more
    // than downtown, and one honest upscaled level beats a grey square.
    maxNativeZoom: 19,
  ),
  MapTileProviderOption(
    id: MapProvider.carto,
    label: 'Carto Voyager',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    // Vector-derived, renders cleanly at z20+.
    maxNativeZoom: 20,
  ),
  MapTileProviderOption(
    id: MapProvider.noMap,
    label: 'No Map (markers only)',
    urlTemplate: '',
    // No tiles to fetch; the camera cap comes from any visible MBTiles overlay.
    maxNativeZoom: 20,
  ),
];

String normalizeMapProviderId(String providerId) {
  // Keep legacy 'satellite' working.
  if (providerId == MapProvider.satellite) {
    return MapProvider.esriSat;
  }

  if (providerId == MapProvider.openTopoLegacy) {
    return MapProvider.topo;
  }
  if (providerId == MapProvider.usgsSatelliteLegacy) {
    return MapProvider.usgsSat;
  }
  if (providerId == MapProvider.humanitarianLegacy) {
    return MapProvider.hot;
  }
  if (providerId == MapProvider.esriSatelliteLegacy) {
    return MapProvider.esriSat;
  }
  if (providerId == MapProvider.cartoVoyagerLegacy) {
    return MapProvider.carto;
  }

  return providerId;
}

MapTileProviderOption tileProviderForId(String providerId) {
  final normalized = normalizeMapProviderId(providerId);
  return kMapTileProviderOptions.firstWhere(
    (o) => o.id == normalized,
    orElse: () => kMapTileProviderOptions.firstWhere(
      (o) => o.id == MapProvider.mapnik,
    ),
  );
}
