# Integration: AI Assistants via REST API

For AI tools that don't support the Model Context Protocol (MCP), OpenMemory provides a REST API for reading and writing memories.

This guide uses a Telegram AI assistant as an example, but the same approach works for any tool that can make HTTP requests.

## How It Works

```
AI Assistant  ──curl/HTTP──▶  OpenMemory API (:8765)  ──▶  Qdrant + Ollama
```

Unlike MCP (which provides native tool integration), REST access requires the AI tool to execute curl commands or HTTP requests directly.

## API Endpoints

### List Memories

```bash
curl -s "http://localhost:8765/api/v1/memories/?user_id=your-username"
```

Response:
```json
{
  "items": [
    {"id": "...", "content": "Prefers TypeScript over JavaScript", "created_at": "..."},
    {"id": "...", "content": "Uses Docker for all services", "created_at": "..."}
  ],
  "total": 42
}
```

### Add a Memory

```bash
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "The project uses PostgreSQL 16 with pgvector.",
    "user_id": "your-username",
    "agent_id": "your-tool-name"
  }'
```

- `text`: The content to process (mem0 extracts atomic facts from this)
- `user_id`: Your OpenMemory user ID
- `agent_id`: Identifies which tool wrote this memory

### Filter Memories

```bash
curl -s -X POST http://localhost:8765/api/v1/memories/filter \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "your-username"}'
```

> **Note**: The REST `filter` endpoint does metadata filtering only. For semantic (vector similarity) search, use the MCP `search_memory` tool via Claude Code or similar MCP clients.

## Setup for Your AI Tool

### 1. Add API Instructions

In your AI tool's configuration file (e.g., system prompt, AGENTS.md, etc.), add the curl commands above. See [config/openclaw-agents-snippet.md](../config/openclaw-agents-snippet.md) for a ready-to-use template.

### 2. Define Write Rules

Tell your AI tool when to write to OpenMemory:

| Write | Skip |
|-------|------|
| User preferences and habits | Temporary session details |
| Architecture decisions and reasoning | API keys / credentials |
| Important bug fixes and solutions | One-off debugging sessions |
| Cross-tool shared context | Minor fixes (typos, formatting) |

### 3. Test the Connection

```bash
# Verify API is accessible
curl -s http://localhost:8765/docs | head -1

# Write a test memory
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test: REST API integration works.", "user_id": "your-username", "agent_id": "test"}'

# Read it back
curl -s "http://localhost:8765/api/v1/memories/?user_id=your-username&size=5"
```

## Limitations of REST vs MCP

| Feature | MCP | REST |
|---------|-----|------|
| Semantic search | Yes (`search_memory`) | No (metadata filter only) |
| Native tool integration | Yes (appears as built-in tool) | No (requires curl execution) |
| Streaming | Yes (SSE) | No |
| Write memories | Yes | Yes |
| List memories | Yes | Yes |
| Delete memories | Yes | Yes |

## Dashboard

You can always browse and manage memories visually at:
- **Dashboard UI**: http://localhost:3080
- **API Docs**: http://localhost:8765/docs (Swagger UI)
