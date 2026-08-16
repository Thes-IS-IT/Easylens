# EasyLens - Data Dictionary Specification

---

### 01 — OVERVIEW & SCHEMA STANDARD

This data dictionary outlines all field definitions, data types, nullability constraints, and architectural descriptions for entities stored across **Local SQLite**, **Cloudflare D1 SQL**, **Cloudflare R2 Storage**, and **Firebase Firestore**.

---

### 02 — SIMPLIFIED DATA DICTIONARY SUMMARY

| Entity / Table | Core Purpose | Key Attributes | Data Tier |
| :--- | :--- | :--- | :--- |
| **`users`** | Stores user profile, preferences, and accessibility settings. | `user_id`, `email`, `full_name`, `preferred_language` | Cloudflare D1 / Firebase |
| **`emergency_contacts`** | Stores emergency contact numbers for SOS alerts. | `contact_id`, `user_id`, `contact_name`, `phone_number` | Cloudflare D1 / SQLite |
| **`incident_logs`** | Records hazard detections, emergency SOS events, and location. | `log_id`, `user_id`, `incident_type`, `latitude`, `longitude` | Cloudflare D1 / SQLite |
| **`storage_assets`** | Maps image files uploaded to Cloudflare R2 bucket. | `asset_id`, `log_id`, `r2_object_key`, `public_url` | Cloudflare R2 / D1 |
| **`saved_places`** | Stores favorite navigation destinations and geocoded targets. | `place_id`, `user_id`, `label`, `latitude`, `longitude` | Local SQLite / D1 |

---

### 03 — DETAILED DATA DICTIONARY TABLES

#### Entity: `users`
* **Description**: Holds user authentication metadata and accessibility preferences (speech rate, pitch, language).
* **Storage Location**: Cloudflare D1 (`users` table) & Firebase Auth.

| Field Name | Data Type | Nullable | Key Type | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `user_id` | `VARCHAR(64)` | No | PK | Unique identifier assigned by Firebase Auth UUID. |
| `email` | `VARCHAR(255)`| No | Unique | User's registered email address. |
| `full_name` | `VARCHAR(100)`| No | - | Full display name of the user. |
| `phone_number` | `VARCHAR(20)` | Yes | - | User's primary mobile phone number. |
| `preferred_language`| `VARCHAR(10)` | No | - | Primary accessibility language code (`en` or `tl`). Default: `en`. |
| `speech_rate` | `FLOAT` | No | - | TTS speech rate modifier ($0.1 - 1.0$). Default: `0.5`. |
| `voice_pitch` | `FLOAT` | No | - | TTS voice pitch modifier ($0.5 - 1.5$). Default: `1.0`. |
| `haptic_feedback_enabled` | `BOOLEAN` | No | - | Toggle flag for tactile vibration pulse alerts (`0` or `1`). |
| `created_at` | `TIMESTAMP` | No | - | ISO-8601 timestamp of user account creation. |
| `last_login` | `TIMESTAMP` | Yes | - | Timestamp of most recent app session. |

---

#### Entity: `emergency_contacts`
* **Description**: Registered emergency contacts notified during SOS triggers.
* **Storage Location**: Cloudflare D1 & Local SQLite cache (`emergency_contacts`).

| Field Name | Data Type | Nullable | Key Type | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `contact_id` | `VARCHAR(64)` | No | PK | Unique UUID generated for each contact. |
| `user_id` | `VARCHAR(64)` | No | FK | Foreign key referencing `users.user_id`. |
| `contact_name` | `VARCHAR(100)`| No | - | Full name of emergency contact person. |
| `phone_number` | `VARCHAR(20)` | No | - | Valid mobile number receiving SMS location alerts. |
| `relationship` | `VARCHAR(50)` | Yes | - | Relationship (e.g., Parent, Spouse, Caregiver). |
| `is_primary` | `BOOLEAN` | No | - | `1` if primary contact called first during SOS; else `0`. |
| `added_at` | `TIMESTAMP` | No | - | Timestamp when contact was bound to account. |

---

#### Entity: `incident_logs`
* **Description**: Records real-time navigational hazard detections and SOS alerts.
* **Storage Location**: Cloudflare D1 (`incident_logs`) & Local SQLite.

| Field Name | Data Type | Nullable | Key Type | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `log_id` | `VARCHAR(64)` | No | PK | Unique UUID assigned per incident event. |
| `user_id` | `VARCHAR(64)` | No | FK | Foreign key referencing `users.user_id`. |
| `incident_type` | `VARCHAR(50)` | No | - | Category (`HAZARD_DETECTED`, `SOS_TRIGGERED`, `OCR_READ`). |
| `latitude` | `DOUBLE` | Yes | - | GPS latitude coordinate ($WGS84$). |
| `longitude` | `DOUBLE` | Yes | - | GPS longitude coordinate ($WGS84$). |
| `hazard_label` | `VARCHAR(100)`| Yes | - | Label of detected obstacle (e.g., `stairs`, `vehicle`, `curb`). |
| `confidence_score` | `FLOAT` | Yes | - | TFLite MobileNetV2 confidence rating ($0.0 - 1.0$). |
| `sos_triggered` | `BOOLEAN` | No | - | `1` if SOS panic alert was activated; else `0`. |
| `timestamp` | `TIMESTAMP` | No | - | Event timestamp (UTC). |

---

#### Entity: `storage_assets`
* **Description**: Maps uploaded diagnostic images and snapshots stored in Cloudflare R2 bucket.
* **Storage Location**: Cloudflare R2 Bucket & Cloudflare D1 metadata index.

| Field Name | Data Type | Nullable | Key Type | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `asset_id` | `VARCHAR(64)` | No | PK | Unique asset identifier. |
| `log_id` | `VARCHAR(64)` | No | FK | Foreign key referencing `incident_logs.log_id`. |
| `r2_object_key` | `VARCHAR(255)`| No | - | S3/R2 storage path key (e.g., `logs/2026/img_102.jpg`). |
| `public_url` | `VARCHAR(512)`| No | - | HTTPS access URL for snapshot retrieval. |
| `file_size_bytes` | `INTEGER` | No | - | Size of image payload in bytes. |
| `content_type` | `VARCHAR(50)` | No | - | MIME type (e.g., `image/jpeg`). |
| `uploaded_at` | `TIMESTAMP` | No | - | Timestamp when direct AWS SigV4 upload completed. |

---

#### Entity: `saved_places`
* **Description**: Geocoded destination targets for turn-by-turn navigation.
* **Storage Location**: Local SQLite & Cloudflare D1.

| Field Name | Data Type | Nullable | Key Type | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `place_id` | `VARCHAR(64)` | No | PK | Unique identifier for saved place entry. |
| `user_id` | `VARCHAR(64)` | No | FK | Foreign key referencing `users.user_id`. |
| `label` | `VARCHAR(100)`| No | - | User-friendly name (e.g., `Home`, `Work`, `Pharmacy`). |
| `address` | `TEXT` | No | - | Full formatted street address string. |
| `latitude` | `DOUBLE` | No | - | Latitude coordinate. |
| `longitude` | `DOUBLE` | No | - | Longitude coordinate. |
| `created_at` | `TIMESTAMP` | No | - | Timestamp when place was bookmarked. |
