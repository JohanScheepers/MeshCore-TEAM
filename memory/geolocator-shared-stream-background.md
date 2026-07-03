---
name: geolocator-shared-stream-background
description: iOS gotcha — all Geolocator.getPositionStream callers share one native session; first caller's settings win
metadata:
  type: project
---

geolocator reuses a single cached position stream / native CLLocationManager for
every `Geolocator.getPositionStream` caller. The FIRST caller's `locationSettings`
are applied to the native session; later callers silently get the same stream and
their settings are ignored (`MethodChannelGeolocator.getPositionStream`).

**Why:** On iOS, if any caller subscribes first with foreground-only settings, the
shared session lacks `allowsBackgroundLocationUpdates`, so the app loses its
background execution assertion and iOS suspends it (and telemetry) ~5s after
backgrounding; the blue location indicator never appears. This was the actual cause
of the "iOS background tracking doesn't work" bug — the map screen (home tab) won
the race over the telemetry sender.

**How to apply:** Every position-stream caller (map view, telemetry sender) MUST use
`buildAppLocationSettings()` in [lib/utils/location_settings.dart](lib/utils/location_settings.dart)
which sets `allowBackgroundLocationUpdates`/`showBackgroundLocationIndicator` on iOS.
Never call `Geolocator.getPositionStream` with a bare `LocationSettings`. Requires
"Always"/"While Using" auth + `location` in Info.plist `UIBackgroundModes` (present).
