# Local storage architecture

`SettingsService` persists user-facing settings with `shared_preferences` and
notifies listening UI after updates. Services such as notifications, ESP32
connection settings, face profiles, emergency contacts, and journals manage
their own local state/persistence paths.

`StorageService` is an abstraction with an `InMemoryStorageService`
implementation; it is not the general runtime persistence layer. Firebase,
Cloudflare D1, and R2 are optional integrations, not replacements for the local
settings mechanism.

See the [services reference](source-of-truth/04_services_reference.md) for
ownership and the [configuration guide](SECURITY_CONFIGURATION.md) for cloud
credentials.
