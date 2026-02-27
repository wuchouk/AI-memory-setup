# Architecture

## The Problem: AI Amnesia

Modern AI coding assistants (Claude Code, Cursor, etc.) and AI chatbots each maintain their own isolated memory. When you use multiple AI tools in your workflow, each one starts fresh every session, and none of them know what the others have learned.

This creates real problems:

- **Duplicated context**: You explain the same preferences, decisions, and project background to each tool separately
- **Inconsistent knowledge**: Tool A doesn't know that Tool B changed a critical config yesterday
- **Lost institutional knowledge**: Important debugging insights, architecture decisions, and user preferences are scattered across multiple isolated memory systems
- **Session amnesia**: Even within a single tool, long-running context gets lost between sessions

### Why existing solutions fall short

| Approach | Limitation |
|----------|-----------|
| Tool-specific memory (e.g., Claude's auto-memory) | Siloed — other tools can't access it |
| Manual documentation (README, wikis) | Requires discipline, gets stale quickly |
| Copy-pasting context | Tedious, error-prone, doesn't scale |
| Cloud memory services | Privacy concerns, API costs, vendor lock-in |

## The Solution: A Local Shared Memory Layer

**OpenMemory** acts as a unified fact database that all your AI tools can read from and write to:

- One source of truth for stable facts (preferences, decisions, configs)
- Semantic vector search — find relevant memories by meaning, not just keywords
- Automatic fact extraction — mem0 distills conversations into atomic facts
- Flexible LLM backend — use **OpenAI API** (recommended, ~$0.17/month, faster and more reliable) or **local Ollama** (free, fully private, works offline)

## Architecture Diagram

```
┌─────────────────┐     MCP (SSE)      ┌──────────────────────┐
│  Claude Code     │───────────────────▶│                      │
│  (MCP client)    │                    │   OpenMemory API     │──▶ Qdrant (vectors)
└─────────────────┘                    │   (FastAPI :8765)    │──▶ SQLite (metadata)
                                       │                      │
┌─────────────────┐     REST API       │                      │──▶ LLM Provider
│  AI Assistant    │───────────────────▶│                      │     (OpenAI API or
│  (REST client)   │  curl localhost    └──────────────────────┘      local Ollama)
└─────────────────┘
                                       ┌──────────────────────┐
                                       │   Dashboard UI       │
                                       │   (Next.js :3080)    │
                                       └──────────────────────┘
```

## Component Roles

### OpenMemory API (FastAPI)

The central hub. Receives memory read/write requests, delegates to the configured LLM provider for fact extraction and embedding, stores results in Qdrant.

- **Port**: 8765
- **Protocols**: MCP (SSE) for Claude Code, REST for other tools
- **Key endpoints**: `/api/v1/memories/`, `/api/v1/config/`, `/mcp/claude-code/sse/{user_id}`

### LLM Provider

OpenMemory uses an LLM for fact extraction and an embedding model for vector search. You can choose between two providers:

| Provider | LLM Model | Embedding Model | Dims | Speed | Cost | Chinese accuracy |
|----------|-----------|-----------------|------|-------|------|------------------|
| **OpenAI (recommended)** | gpt-4.1-nano | text-embedding-3-small | 1536 | ~5-7s | ~$0.17/mo | Excellent |
| Ollama (local) | qwen3:8b | nomic-embed-text | 768 | ~25s | Free | Inconsistent |

**Why OpenAI is recommended:** Faster writes (~5-7s vs ~25s), significantly better Chinese/CJK fact extraction accuracy, and negligible cost at typical personal usage volumes. Your memory text still stays in your local Qdrant database — only the extraction and embedding API calls go to OpenAI.

**Why you might still choose Ollama:** Zero cloud dependency, no data leaves your machine at all, works fully offline, and no API key required.

### Qdrant (Vector Database)

Stores memory embeddings for semantic search. When you search for "my preferred code style", it finds relevant memories even if they don't contain those exact words.

- **Port**: 6333
- **Dimensions**: 1536 (OpenAI text-embedding-3-small) or 768 (Ollama nomic-embed-text) — must match your chosen embedding model
- **Storage**: Docker volume (`mem0_storage`)

> **Important**: If you switch providers, you must delete the existing Qdrant collection and re-index, because the vector dimensions differ.

### Dashboard UI (Next.js)

Visual interface to browse, search, and manage memories.

- **Port**: 3080 (mapped from container's 3000 to avoid conflicts)

## Data Flow

### Writing a memory

```
User/AI tool → POST /api/v1/memories/
  → mem0 engine → LLM Provider (extract atomic facts from text)
  → LLM Provider (generate embedding vector)
  → Qdrant (store vector + metadata)
  → Return extracted fact or null (if no new facts found)
```

### Reading/searching memories

```
User/AI tool → GET /api/v1/memories/ (list) or MCP search_memory (semantic)
  → Qdrant (vector similarity search)
  → Return ranked results
```

## Design Decisions

### Why MCP + REST (not MCP-only)?

Not all AI tools support the Model Context Protocol. Claude Code has native MCP support, but other tools (custom bots, scripts) need REST. OpenMemory exposes both:

- **MCP (SSE)**: For MCP-capable clients like Claude Code — provides `search_memory`, `add_memories`, etc. as native tools
- **REST**: For everything else — simple curl-based access

### Why `restart: always` on all containers?

The system should survive reboots without manual intervention. Combined with Ollama's `brew services` auto-start, the entire stack comes back online automatically after a power cycle.

### Why port 3080 for the UI?

Ports 3000, 3001, and 3002 are commonly used by development servers (Next.js, Create React App, etc.). Port 3080 avoids conflicts.

### Why hardcode USER in docker-compose.yml?

Docker's `environment: - USER` inherits from the host's `$USER`, which may differ from your OpenMemory username. Hardcoding prevents subtle "user not found" errors.

## RAM Budget

### With OpenAI API (recommended)

| Component | RAM Usage |
|-----------|-----------|
| macOS system | ~4GB |
| Docker (FastAPI + Qdrant) | ~2-3GB |
| Other applications | ~5-7GB |
| **Total** | **~6-8GB** (Ollama not needed) |

No local LLM required — fact extraction and embedding are handled by OpenAI's API. This frees up significant RAM for other applications.

### With Ollama (local)

| Component | RAM Usage |
|-----------|-----------|
| macOS system | ~4GB |
| Ollama (qwen3:8b + nomic-embed-text) | ~7GB (unloads when idle) |
| Docker (FastAPI + Qdrant) | ~2-3GB |
| Other applications | ~5-7GB |
| **Total** | **~18-21GB / 24GB** |

**Minimum recommended**: 16GB RAM (use a smaller LLM like qwen3:4b)
**Comfortable**: 24GB+ RAM

## Future Considerations

- **Multi-machine access**: Use Tailscale or similar VPN to access from other devices
- **Backup strategy**: Export Qdrant snapshots periodically
- **Model upgrades**: Swap models for newer ones as they become available
