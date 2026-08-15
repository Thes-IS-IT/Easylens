# Security Policy 🛡️

The **EasyLens** research and engineering team takes security, user privacy, and data protection with utmost seriousness. Because EasyLens assists visually impaired and neurodivergent individuals in safety-critical spatial navigation and emergency SOS dispatch, maintaining the confidentiality, integrity, and availability of our system is a top priority.

---

## 🎓 Research Team & Maintainers

This security policy is maintained by the undergraduate thesis research team at **Holy Angel University (HAU)**:

- **Graciella Mhervie D. Jimenez**
- **Jian Kalel D. Marquez**
- **Arron Kian M. Parejas**
- **Jenica Sarah B. Tongol**

---

## 🔒 Supported Versions

Only the latest active development release branch receives security updates and vulnerability patches.

| Version | Supported | Notes |
|---|---|---|
| `v1.0.x` (Current) | :white_check_mark: | Active Thesis / Production Release |
| `< v1.0.0` | :x: | Legacy Alpha / Experimental Prototypes |

---

## 🛡️ Security Architecture & Privacy by Design

EasyLens adheres to strict **Privacy by Design** and edge-first architectural standards:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        EasyLens Security Model                         │
├───────────────────────────────────┬────────────────────────────────────┤
│ 🔒 On-Device Processing (Edge AI) │ ☁️ Authenticated Cloud & Storage   │
│ - TFLite MobileNetV2 SSD in RAM   │ - Firebase UID granular isolation  │
│ - ML Kit OCR & Face Vectors local │ - Cloudflare R2 AWS SigV4 HMAC     │
│ - Gemma 2B LLM runs 100% offline  │ - Cloudflare D1 parameterized SQL  │
│ - Zero video transmission to cloud│ - MensaHero Emergency SMS Gateway  │
└───────────────────────────────────┴────────────────────────────────────┘
```

### 1. Edge-First Vision & Privacy Isolation
- **Ephemeral Frame Processing:** Camera preview frames from either the mobile camera or the ESP32-CAM MJPEG stream are processed ephemerally in RAM isolates. Video frames are **never** uploaded or recorded to cloud servers without explicit user-initiated capture.
- **On-Device LLM (Gemma 2B):** English voice queries and scene comprehension with Buddy execute entirely offline on-device, ensuring zero conversational telemetry leaves the user's phone.
- **Facial Landmark Encryption:** Face registration extracts only 25-dimensional geometric mathematical feature vectors rather than storing raw biometric face photographs in plaintext.

### 2. Credential Management & API Key Protection
- All third-party credentials (`GEMINI_API_KEY`, `GOOGLE_MAPS_KEY`, `MENSAHERO_API_KEY`, `S3_API` credentials) are managed via `.env` with `flutter_dotenv`.
- Production credentials are never checked into version control (`.gitignore` enforces isolation).
- GitHub Actions CI/CD pipelines inject keys dynamically via encrypted repository secrets.

### 3. Cloud Storage & Data Security
- **Cloudflare R2 Object Storage:** Uploads use client-side **AWS Signature Version 4 (HMAC-SHA256)** signing to generate time-limited authenticated requests. No permanent master API tokens are exposed in public network traffic.
- **Firebase Security Rules:** Firestore database and Firebase Storage rules enforce strict per-user authentication. Users can only read and write their own documents matching `request.auth.uid`.

### 4. Emergency SOS & Caregiver Protocol
- SOS dispatch triggers direct SMS transmission via the **MensaHero** gateway with verified sender authentication.
- GPS coordinates broadcast during emergencies are validated to prevent coordinate spoofing and replay attacks.

### 5. AI Guardrails & Hallucination Defense
- RAG and multimodal prompt templates include strict system guardrails (`ai_memory_and_guardrails.md`) preventing the generation of hazardous walking directions.
- Direct spatial proximity alerts (Stop, Avoid Left, Avoid Right, Slow Down) are computed deterministically via mathematical bounding box metrics rather than unconstrained LLM outputs.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability, privacy leak, or critical bug in EasyLens:

1. **Do NOT open a public GitHub issue.**
2. Please report your findings privately via GitHub Security Advisories or by emailing the project maintainers:
   - **Lead Researcher / Architect:** `parejasarronkian@gmail.com`
   - Subject line: `[SECURITY] EasyLens Vulnerability Report - <Brief Description>`
3. Please include in your report:
   - A description of the vulnerability and its potential impact.
   - Step-by-step instructions or proof-of-concept (PoC) to reproduce the issue.
   - Target device / OS environment (Android, iOS, ESP32).
   - Any suggested remediations or mitigations.

### Response Timeline
- **Acknowledgment:** Within 48 hours.
- **Assessment & Triage:** Within 5 business days.
- **Fix & Disclosure:** Coordinated release and credit acknowledgment in release notes.

---

## 🏆 Security Acknowledgments

We appreciate the responsible security community and academic peers who help keep EasyLens and its users safe. Verified security contributions and bug disclosures will be credited in our official release notes and documentation.
