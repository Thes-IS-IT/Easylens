# Buddy knowledge, memory, and guardrails

The application knowledge base is bundled at
`assets/models/buddy_knowledge.json` and loaded during startup. `RagService`
builds an in-memory keyword index and cached TF-IDF engines for retrieval; it
does not implement a vector database or durable conversational memory.

`JournalService` provides a separate local journal capability. Chat-history
display and assistant-context behavior should therefore be treated as UI/service
state unless code explicitly persists it.

Local-only Buddy requests contain scope guardrails for off-topic prompts. The
repository tests cover representative scope rejection, curated responses, and
knowledge retrieval. Online Gemini answers are remote-model output and require
appropriate key, network, privacy, and safety controls.

For implementation details, see [AI & ML pipeline](source-of-truth/05_ai_ml_pipeline.md).
