# 06 — Walking navigation system

`NavigationScreen` obtains location permission and position updates through `Geolocator`, renders maps through `google_maps_flutter`, calls OSRM for route geometry, and can call Google Places text search when `GOOGLE_MAPS_KEY` exists. It tracks destination/route/step state locally while `ActiveNavigationService` holds shared active-navigation information.

Guidance is spoken through the navigation/TTS services. Distances use `Geolocator.distanceBetween`; units follow the selected unit preference.

## Safety boundary

This feature is guidance only. Route geometry, GPS fixes, third-party maps, camera observations, and audio can be stale, wrong, unavailable, or unsuitable for pedestrian access. Do not present it as collision avoidance, hazard detection, emergency dispatch confirmation, or a substitute for mobility aids and situational awareness.

## Change checklist

- Test permission denied, location disabled, no network, and missing Maps key.
- Avoid unbounded TTS repetition; stop speech when cancelling/disposal requires it.
- Verify destination/waypoint completion manually on a physical device.
- Keep external endpoint failures visible but non-fatal.
