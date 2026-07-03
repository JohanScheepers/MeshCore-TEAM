// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0

import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// Builds the platform location settings used for **every** position stream in
/// the app.
///
/// CRITICAL — why this must be shared:
///
/// geolocator keeps a single cached position stream and reuses it for every
/// `Geolocator.getPositionStream` caller.  The **first** caller's settings are
/// the ones applied to the native `CLLocationManager`; later callers silently
/// receive that same stream and their own settings are ignored
/// (see `MethodChannelGeolocator.getPositionStream`).
///
/// On iOS the app therefore needs *every* caller (the map view and the
/// telemetry sender) to request background updates.  If any caller subscribes
/// first with foreground-only settings, the shared session ends up without
/// `allowsBackgroundLocationUpdates`, the app loses its background execution
/// assertion, and iOS suspends it (and telemetry) a few seconds after it is
/// backgrounded — and the blue background-location indicator never appears.
///
/// Requires "Always" (or "While Using") authorization plus the `location`
/// `UIBackgroundModes` entry in Info.plist.
LocationSettings buildAppLocationSettings({int distanceFilter = 5}) {
  if (Platform.isIOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
      allowBackgroundLocationUpdates: true,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      activityType: ActivityType.other,
    );
  }
  if (Platform.isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }
  return LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: distanceFilter,
  );
}
