# Security Policy

The EasyLens research and engineering team takes security, user privacy, and data protection with utmost seriousness. Because EasyLens assists visually impaired and neurodivergent individuals in safety-critical spatial navigation and emergency SOS dispatch, maintaining the confidentiality, integrity, and availability of our system is a priority.

---

### 01 — RESEARCH TEAM & MAINTAINERS

This security policy is maintained by the undergraduate thesis research team at **Holy Angel University (HAU)**:

- **Graciella Mhervie D. Jimenez**
- **Jian Kalel D. Marquez**
- **Arron Kian M. Parejas**
- **Jenica Sarah B. Tongol**

---

### 02 — SUPPORTED VERSIONS

Only the latest active development release branch receives security updates and vulnerability patches.

| Version | Supported | Notes |
|---|---|---|
| `v1.0.x` (Current) | Yes | Active Thesis / Production Release |
| `< v1.0.0` | No | Legacy Alpha / Experimental Prototypes |

---

### 03 — SECURITY ARCHITECTURE & PRIVACY BY DESIGN

EasyLens adheres to Privacy by Design and edge-first architectural standards:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        EasyLens Security Model                         │
├───────────────────────────────────┬────────────────────────────────────┤
│ On-Device Processing (Edge AI)    │ Authenticated Cloud & Storage      │
│ - TFLite MobileNetV2 SSD in RAM   │ - Firebase UID granular isolation  │
│ - ML Kit OCR & Face Vectors local │ - Cloudflare R2 AWS SigV4 HMAC     │
│ - Gemma 2B LLM runs offline       │ - Cloudflare D1 parameterized SQL  │
│ - Zero video transmission to cloud│ - MensaHero Emergency SMS Gateway  │
└───────────────────────────────────┴────────────────────────────────────┘
```

#### 1. Edge-First Vision & Privacy Isolation
- **Ephemeral Frame Processing:** Camera preview frames from either the mobile camera or the ESP32-CAM MJPEG stream are processed ephemerally in RAM isolates. Video frames are never uploaded or recorded to cloud servers without explicit user-initiated capture.
- **On-Device LLM (Gemma 2B):** English voice queries and scene comprehension with Buddy execute offline on-device, ensuring conversational telemetry remains on the phone.
- **Facial Landmark Encryption:** Face registration extracts 25-dimensional geometric mathematical feature vectors rather than storing biometric face photographs in plaintext.

#### 2. Credential Management & API Key Protection
- Third-party credentials (`GEMINI_API_KEY`, `GOOGLE_MAPS_KEY`, `MENSAHERO_API_KEY`, `S3_API`) are managed via `.env` with `flutter_dotenv`.
- Production credentials are not checked into version control (`.gitignore` enforces isolation).
- CI/CD pipelines inject keys dynamically via encrypted repository secrets.

#### 3. Cloud Storage & Data Security
- **Cloudflare R2 Object Storage:** Uploads use client-side AWS Signature Version 4 (HMAC-SHA256) signing to generate time-limited authenticated requests. Master API tokens are not exposed in public network traffic.
- **Firebase Security Rules:** Firestore database and Firebase Storage rules enforce per-user authentication. Users can only read and write their own documents matching `request.auth.uid`.

#### 4. Emergency SOS & Caregiver Protocol
- SOS dispatch triggers direct SMS transmission via the MensaHero gateway with verified sender authentication.
- GPS coordinates broadcast during emergencies are validated to prevent coordinate spoofing and replay attacks.

#### 5. AI Guardrails & Hallucination Defense
- RAG and multimodal prompt templates include system guardrails (`ai_memory_and_guardrails.md`) preventing the generation of hazardous walking directions.
- Spatial proximity alerts (Stop, Avoid Left, Avoid Right, Slow Down) are computed deterministically via mathematical bounding box metrics rather than unconstrained LLM outputs.

---

### 04 — REPORTING A VULNERABILITY

> **Note:** If a security vulnerability, privacy leak, or critical bug is discovered, do not open a public issue.

Report findings privately via Security Advisories or by emailing the project maintainers:
- **Lead Researcher / Architect:** `parejasarronkian@gmail.com`
- Subject line: `[SECURITY] EasyLens Vulnerability Report - <Brief Description>`

Include the following in the report:
- A description of the vulnerability and its potential impact.
- Step-by-step instructions or proof-of-concept (PoC) to reproduce the issue.
- Target device / OS environment (Android, iOS, ESP32).
- Any suggested remediations or mitigations.

#### Response Timeline
- **Acknowledgment:** Within 48 hours.
- **Assessment & Triage:** Within 5 business days.
- **Fix & Disclosure:** Coordinated release and credit acknowledgment in release notes.

---

### 05 — SECURITY ACKNOWLEDGMENTS

Verified security contributions and bug disclosures will be credited in the official release notes and documentation.
