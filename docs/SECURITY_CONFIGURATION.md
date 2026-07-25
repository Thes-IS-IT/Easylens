# Configuration and security

EasyLens loads `.env` at startup. The file is intentionally ignored by Git;
create it locally and never put real secrets in documentation, source code, or
release builds.

## Environment variables used by the code

| Integration | Variables |
| --- | --- |
| Firebase (optional explicit initialization) | `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET` |
| Google sign-in | `GOOGLE_WEB_CLIENT_ID` |
| Gemini | Any non-empty variable whose name contains `GEMINI` or `GOOGLE_AI` (except Firebase variables); a user may also save a key in Settings |
| Maps place search | `GOOGLE_MAPS_KEY` |
| MensaHero SMS gateway | `MENSAHERO_API_KEY`, `MENSAHERO_BASE_URL`, `MENSAHERO_DEVICE_NAME` |
| Cloudflare R2 | `ACCOUNT_ID`, `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `BUCKET_NAME`, `CLOUDFLARE_R2_PUBLIC_URL` |
| Cloudflare D1 | `ACCOUNT_ID`, `D1_DTABASE`, `TOKEN_VALUE` |
| ElevenLabs TTS | `ELEVEN_LABS` |

`D1_DTABASE` is intentionally spelled exactly as the current implementation
expects. Renaming it requires a code change.

## Platform setup

- Add the Android Google Maps key through the Android application configuration.
- Firebase can use platform configuration files or the explicit Firebase values
  above. If Firebase initialization fails, the app falls back to local mock
  behavior for supported flows.
- Android requests camera, microphone, location, contacts, vibration,
  Bluetooth, and SMS permissions. Exercise only the permissions your build
  actually needs and test their denial paths.
- The ESP32 default stream is `http://192.168.4.1:81/stream`; it can be changed
  from the Devices screen.

## Important security note

The repository currently contains credential-like defaults in application and
Android configuration. Treat those values as exposed: rotate them, restrict
their API permissions and origins, and move the replacement values to managed
secrets before publishing the app. In particular, do not ship R2 long-lived
S3 credentials in a mobile client. Use a server-side signing service or
short-lived scoped upload URLs for production.

## Suggested local `.env` shape

```dotenv
GEMINI_API_KEY=
GOOGLE_MAPS_KEY=
MENSAHERO_API_KEY=
MENSAHERO_BASE_URL=
FIREBASE_API_KEY=
FIREBASE_APP_ID=
FIREBASE_PROJECT_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_STORAGE_BUCKET=
ACCOUNT_ID=
ACCESS_KEY_ID=
SECRET_ACCESS_KEY=
BUCKET_NAME=easylens
CLOUDFLARE_R2_PUBLIC_URL=
D1_DTABASE=
TOKEN_VALUE=
ELEVEN_LABS=
```
