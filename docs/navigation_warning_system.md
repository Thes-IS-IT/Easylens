# Navigation and warning system

`NavigationScreen` combines `Geolocator`, Google Maps rendering, Google place
search (when configured), and OSRM route requests. `ActiveNavigationService`
holds active navigation state; `NavigationVoiceAssistant`, `TtsService`, and
`DangerWarningService` provide spoken and hazard-feedback support.

Routes and alerts are assistive guidance, not a safety-critical navigation
system. GPS, map data, camera inference, and network availability can be
incorrect or unavailable. The app must not claim guaranteed obstacle avoidance
or emergency response.

For state ownership, distance handling, and safe change guidelines, read
[06 — Walking Navigation System](source-of-truth/06_walking_navigation.md).
