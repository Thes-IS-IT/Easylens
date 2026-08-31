# Appendix F: Entity Relationship Diagrams (ERD)

---

## Figure F.1: Conceptual Entity Relationship Diagram

### APA 7th Citation & Metadata
- **Figure Number**: Figure F.1
- **Figure Title**: *Conceptual Entity Relationship Diagram*
- **Manuscript Page**: 182
- **PDF Page**: 190
- **Image Asset**: [fig_f_1_conceptual_erd.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_f_1_conceptual_erd.png)

```
Figure F.1
Conceptual Entity Relationship Diagram

Note. Figure F.1 models the high-level conceptual entities and cardinalities governing the EasyLens relational data architecture.
```

---

### Technical Diagram (Mermaid Conceptual ERD)

```mermaid
erDiagram
    USER ||--o{ EMERGENCY_CONTACT : "registers (1:N)"
    USER ||--o{ INCIDENT_LOG : "triggers (1:N)"
    USER ||--o{ SAVED_PLACE : "saves (1:N)"
    INCIDENT_LOG ||--o| STORAGE_ASSET : "attaches snapshot (1:1)"

    USER {
        string user_id PK
        string email
        string preferred_language
    }
    EMERGENCY_CONTACT {
        string contact_id PK
        string user_id FK
        string phone_number
    }
    INCIDENT_LOG {
        string log_id PK
        string user_id FK
        string hazard_label
    }
    SAVED_PLACE {
        string place_id PK
        string user_id FK
        string label
    }
    STORAGE_ASSET {
        string asset_id PK
        string log_id FK
        string r2_object_key
    }
```

---

## Figure F.2: Relational Entity Relationship Diagram

### APA 7th Citation & Metadata
- **Figure Number**: Figure F.2
- **Figure Title**: *Relational Entity Relationship Diagram*
- **Manuscript Page**: 183
- **PDF Page**: 191
- **Image Asset**: [fig_f_2_relational_erd.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_f_2_relational_erd.png)

```
Figure F.2
Relational Entity Relationship Diagram

Note. Figure F.2 details the physical relational schema, field definitions, primary keys (PK), foreign keys (FK), and referential integrity constraints implemented across the local SQLite database and Cloudflare D1 serverless database.
```

---

### Technical Diagram (Mermaid Relational ERD)

```mermaid
erDiagram
    USERS ||--o{ EMERGENCY_CONTACTS : "has registered (1:N)"
    USERS ||--o{ INCIDENT_LOGS : "records (1:N)"
    USERS ||--o{ SAVED_PLACES : "saves (1:N)"
    INCIDENT_LOGS ||--o| STORAGE_ASSETS : "attaches snapshot (1:1)"

    USERS {
        string user_id PK
        string email
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

    SAVED_PLACES {
        string place_id PK
        string user_id FK
        string label
        string address
        float latitude
        float longitude
        datetime created_at
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
```
