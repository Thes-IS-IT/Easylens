# EasyLens - Entity Relationship Diagram (ERD) Specification

---

### 01 — OVERVIEW & DATA ARCHITECTURE

This document defines the relational and document data architecture for **EasyLens**. Data persistence spans **Local SQLite Caching**, **Cloudflare D1 SQL Serverless Edge Database**, **Cloudflare R2 Object Storage**, and **Firebase Authentication & Firestore**.

---

### 02 — SIMPLIFIED ENTITY RELATIONSHIP DIAGRAM

The high-level ERD models core relationships between Users, Emergency Contacts, Detection Incident Logs, Navigational Saved Places, and Storage Assets.

```mermaid
erDiagram
    USER ||--o{ EMERGENCY_CONTACT : registers
    USER ||--o{ INCIDENT_LOG : triggers
    USER ||--o{ SAVED_PLACE : stores
    INCIDENT_LOG ||--o| STORAGE_ASSET : uploads
```

---

### 03 — DETAILED ENTITY RELATIONSHIP DIAGRAM

The detailed ERD specifies exact primary keys (PK), foreign keys (FK), data types, constraints, and relational cardinality across the relational schema.

```mermaid
erDiagram
    USERS {
        string user_id PK
        string email
        string full_name
        string phone_number
        string preferred_language
        float speech_rate
        float voice_pitch
        boolean haptic_feedback_enabled
        datetime created_at
        datetime last_login
    }

    EMERGENCY_CONTACTS {
        string contact_id PK
        string user_id FK
        string contact_name
        string phone_number
        string relationship
        boolean is_primary
        datetime added_at
    }

    INCIDENT_LOGS {
        string log_id PK
        string user_id FK
        string incident_type
        float latitude
        float longitude
        string hazard_label
        float confidence_score
        boolean sos_triggered
        datetime timestamp
    }

    STORAGE_ASSETS {
        string asset_id PK
        string log_id FK
        string r2_object_key
        string public_url
        int file_size_bytes
        string content_type
        datetime uploaded_at
    }

    SAVED_PLACES {
        string place_id PK
        string user_id FK
        string label
        string address
        float latitude
        float longitude
        datetime created_at
    }

    USERS ||--o{ EMERGENCY_CONTACTS : "has registered"
    USERS ||--o{ INCIDENT_LOGS : "records"
    USERS ||--o{ SAVED_PLACES : "saves"
    INCIDENT_LOGS ||--o| STORAGE_ASSETS : "attaches snapshot"
```
