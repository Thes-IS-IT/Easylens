# Feature guide

EasyLens currently exposes these major feature areas:

| Area | Entry implementation |
| --- | --- |
| Onboarding, account, and profile | `lib/screens/welcome`, `login`, `signup`, and `settings` |
| Home dashboard and Buddy assistant | `lib/screens/dashboard` |
| Camera vision, object labeling, face registration, and ESP32 stream | `lib/screens/hardware`, `image_labeling`, `face_registration`, and `devices` |
| GPS route guidance and speech navigation | `lib/screens/navigation` |
| SOS and contact management | `lib/screens/emergency` and `contacts` |
| Notification preferences and history | `lib/screens/notifications` |

Implemented features depend on device permissions, model assets, and optional
network/cloud services. Details and known limits are recorded in the
[screens reference](source-of-truth/03_screens_and_navigation.md),
[AI/ML reference](source-of-truth/05_ai_ml_pipeline.md), and
[known issues](source-of-truth/07_known_issues.md).
