# Buddy AI architecture

Buddy is implemented by `lib/services/rag_service.dart`. It loads local
knowledge from `assets/models/buddy_knowledge.json`, retrieves context with an
inverted index/TF-IDF approach, and produces an answer through either local
Gemma or Gemini.

- The **Local AI** setting attempts Gemma through `flutter_gemma` when a model
  exists in app storage.
- The online path uses the Google Generative AI package and an available Gemini
  key.
- The active language, selected mode, model availability, and network/API
  failures affect the actual route; it is not a fixed English/Filipino split.
- Buddy responses may include `[NAVIGATE: target]` directives consumed by the
  UI. They are removed from displayed assistant text.

See [05 — AI & ML Pipeline](source-of-truth/05_ai_ml_pipeline.md) for the
complete flow, asset requirements, guardrails, and test coverage.
