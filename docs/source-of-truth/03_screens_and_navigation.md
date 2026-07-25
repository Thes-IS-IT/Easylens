# 03 — Screens and navigation

| Area | Primary screens | Purpose |
| --- | --- | --- |
| Entry and account | `welcome`, `login`, `signup`, `onboarding` | Introduction, authentication, profile/preferences collection |
| Dashboard | `dashboard/dashboard_screen.dart`, `dashboard_home.dart` | Tabbed home and Buddy access |
| Vision and devices | `hardware`, `image_labeling`, `devices`, `face_registration` | Device/ESP32 camera workflows, labels, faces, pairing |
| Mobility | `navigation/navigation_screen.dart` | Destination search, map and spoken route guidance |
| Safety | `emergency`, `contacts`, `notifications` | SOS flow, emergency contacts, alerts/preferences |
| Settings | `settings/*` | Appearance, language, voice, units, profile, help, survey |
| Assistant | `rag_assistant/rag_assistant_screen.dart` | Full Buddy/RAG chat screen |

The dashboard also exposes shared controls such as a floating Buddy button and custom navigation bars. Hardware has its own `components/` directory for HUD, camera, controls, pairing, and loading widgets.

## Navigation practices

- Use `Navigator.push(context, AppRoute.to(screen))` for ordinary transitions.
- Use the purpose-specific `AppRoute` transition only where it matches the current flow.
- Camera and continuous-stream screens must stop/restore resources around a route change; see the coding conventions and source implementation.
- Assistant `[NAVIGATE: ...]` directives are interpreted by UI code and are not a security boundary. Validate every supported target explicitly.
