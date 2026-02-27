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
- Fully local — Ollama LLM on your machine, zero cloud API costs, full privacy

## Architecture Diagram

```
┌─────────────────┐     MCP (SSE)      ┌──────────────────────┐
│  Claude Code     │───────────────────▶│                      │
│  (MCP client)    │                    │   OpenMemory API     │──▶ Qdrant (vectors)
└─────────────────┘                    │   (FastAPI :8765)    │──▶ SQLite (metadata)
                                       │                      │
┌─────────────────┐     REST API       │                      │──▶ Ollama (LLM + Embed)
│  AI Assistant    │───────────────────▶│                      │     (localhost:11434)
│  (REST client)   │  curl localhost    └──────────────────────┘
└─────────────────┘
                                       ┌──────────────────────┐
                                       │   Dashboard UI       │
                                       │   (Next.js :3080)    │
                                       └──────────────────────┘
```

## Component Roles

### OpenMemory API (FastAPI)

The central hub. Receives memory read/write requests, delegates to Ollama for fact extraction and embedding, stores results in Qdrant.

- **Port**: 8765
- **Protocols**: MCP (SSE) for Claude Code, REST for other tools
- **Key endpoints**: `/api/v1/memories/`, `/api/v1/config/`, `/mcp/claude-code/sse/{user_id}`

### Ollama (Local LLM)

Runs two models entirely on your machine:

| Model | Role | Size | Why this model |
|-------|------|------|----------------|
| qwen3:8b | Fact extraction | ~5.2GB | Strong multilingual understanding (CJK + English) |
| nomic-embed-text | Vector embeddings | ~274MB | 768-dim vectors, open-source, quality close to OpenAI |

**Why local?** Zero API costs, no data leaves your machine, works offline.

### Qdrant (Vector Database)

Stores memory embeddings for semantic search. When you search for "my preferred code style", it finds relevant memories even if they don't contain those exact words.

- **Port**: 6333
- **Dimensions**: 768 (must match nomic-embed-text)
- **Storage**: Docker volume (`mem0_storage`)

### Dashboard UI (Next.js)

Visual interface to browse, search, and manage memories.

- **Port**: 3080 (mapped from container's 3000 to avoid conflicts)

## Data Flow

### Writing a memory

```
User/AI tool → POST /api/v1/memories/
  → mem0 engine → Ollama (extract atomic facts from text)
  → Ollama (generate embedding vector)
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
- **Model upgrades**: Swap qwen3:8b for newer models as they become available
