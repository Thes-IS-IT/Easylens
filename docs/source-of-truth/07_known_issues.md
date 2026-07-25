# 07 — Known issues and risks

These items were verified from the repository configuration or current tooling on 2026-07-25; they are not historical claims.

| Severity | Finding | Impact / next action |
| --- | --- | --- |
| High | Credential-like defaults exist in client code and Android configuration. | Rotate/restrict affected keys and remove defaults before any public release. Use backend-issued, scoped credentials for uploads and messaging. |
| High | R2 performs SigV4 signing in the mobile client. | A compiled app can expose long-lived S3 credentials; replace with short-lived signed uploads. |
| Medium | `SmsService` has a default gateway key/base URL fallback. | Avoid unexpected production messaging; require explicit configuration and test authorization/error behavior. |
| Medium | CI runs analysis only. | Add tests and build/release checks before relying on CI as a quality gate. |
| Medium | Several optional integrations are not covered by automated tests. | Test camera, ESP32, Firebase, Gemini, navigation, and permissions on supported devices. |
| Low | `flutter analyze --no-fatal-warnings --no-fatal-infos` completes with 10 informational lint findings. | Clean up listed lint findings when touching adjacent code; no analyzer errors were reported. |
| Low | Geolocator emits `MissingPluginException` in the RAG guardrail unit-test run. | The test still passes; use platform integration tests for live location behavior. |

No claim is made here that a previously documented camera/model workaround is still applicable unless it is revalidated against the current code and devices.
