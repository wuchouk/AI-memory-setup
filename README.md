# AI Memory Setup

**A shared memory layer for AI tools — fully local, zero cloud costs.**

[繁體中文版](README.zh-TW.md)

## Why This Exists

If you use multiple AI tools in your workflow (e.g., Claude Code for coding + an AI chatbot for other tasks), you've probably noticed: **they don't talk to each other.**

Each tool maintains its own isolated memory. Claude Code doesn't know what your chatbot discussed yesterday. Your chatbot doesn't know Claude Code just refactored the database schema. You end up repeating the same context, preferences, and decisions to each tool — over and over.

**This project solves that problem.**

It deploys [OpenMemory (mem0)](https://github.com/mem0ai/mem0) as a **unified memory layer** that all your AI tools can read from and write to:

```
┌─────────────────┐                    ┌──────────────────────┐
│  Claude Code     │──── MCP (SSE) ───▶│                      │
└─────────────────┘                    │   OpenMemory API     │──▶ Qdrant (vector DB)
                                       │   (FastAPI)          │
┌─────────────────┐                    │                      │──▶ LLM Provider
│  AI Chatbot      │──── REST API ────▶│                      │    (OpenAI or Ollama)
└─────────────────┘                    └──────────────────────┘
```

### What it gives you

- **Shared context**: Write a preference once, all tools remember it
- **Semantic search**: Find memories by meaning, not just keywords
- **Automatic fact extraction**: mem0 distills conversations into atomic facts
- **Privacy options**: Run fully local with Ollama (no data leaves your machine), or use OpenAI API for faster responses (~$0.17/month)
- **Low cost**: Free with Ollama; ~$0.17/month with OpenAI API
- **Survives reboots**: Auto-start via Docker + brew services

### What problems it solves

| Without shared memory | With shared memory |
|-----------------------|-------------------|
| Repeat your preferences to each tool | Set once, accessible everywhere |
| Tool A doesn't know Tool B's changes | Both read from the same source |
| Debugging insights lost between sessions | Persisted and searchable |
| Context scattered across tools | Unified fact database |

## Quick Start

### Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4)
- Docker Desktop
- Homebrew
- OpenAI API key (recommended) or 16GB+ RAM for local Ollama

### 1. Deploy Docker Stack

```bash
cd ~
git clone https://github.com/mem0ai/mem0.git
cd mem0/openmemory

# Create .env (Option A: OpenAI — recommended)
cat > api/.env << 'EOF'
USER=your-username
OPENAI_API_KEY=sk-proj-your-key-here
EOF

# Or for Ollama (Option B — local, free):
# cat > api/.env << 'EOF'
# USER=your-username
# OPENAI_API_KEY=not-needed
# OLLAMA_HOST=http://host.docker.internal:11434
# EOF

# Customize docker-compose.yml (see config/docker-compose.yml for reference)
# Build and start
make build
NEXT_PUBLIC_USER_ID=your-username \
NEXT_PUBLIC_API_URL=http://localhost:8765 \
docker compose up -d
```

### 2. Configure mem0

```bash
./scripts/configure-mem0.sh
```

> If using Ollama, first run `./scripts/setup-ollama.sh` to install models.

### 3. Connect Your AI Tools

**Claude Code (MCP)**:
```bash
claude mcp add -s user openmemory --transport sse \
  http://localhost:8765/mcp/claude-code/sse/your-username
```

**Other tools (REST)**:
```bash
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{"text": "Content to remember", "user_id": "your-username", "agent_id": "my-tool"}'
```

### 4. Verify

```bash
USER_ID=your-username ./scripts/test-qa.sh all
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System design, component roles, data flow |
| [Deployment Guide](docs/deployment-guide.md) | Full step-by-step deployment |
| [Troubleshooting](docs/troubleshooting.md) | Top 5 issues + FAQ |
| [Claude Code Integration](docs/integration-claude-code.md) | MCP setup for Claude Code |
| [REST API Integration](docs/integration-openclaw.md) | REST access for other tools |
| [QA Test Results](docs/qa-results.md) | 6-level test suite |
| [Environment](docs/environment.md) | Tool versions and configs |

All documents are available in [English](docs/) and [繁體中文](docs/).

## Config Templates

| File | Purpose |
|------|---------|
| [docker-compose.yml](config/docker-compose.yml) | Annotated Docker config |
| [env.example](config/env.example) | Environment variable template |
| [claude-mcp-config.example.json](config/claude-mcp-config.example.json) | MCP server configuration |
| [claude-md-snippet.md](config/claude-md-snippet.md) | CLAUDE.md instructions for Claude Code |
| [openclaw-agents-snippet.md](config/openclaw-agents-snippet.md) | Agent config for REST-based tools |

## Tech Stack

| Component | Tool | Version |
|-----------|------|---------|
| Memory Engine | [mem0 / OpenMemory](https://github.com/mem0ai/mem0) | v1.0.4+ |
| Vector Database | [Qdrant](https://qdrant.tech/) | v1.17.0 |
| LLM (fact extraction) | [OpenAI API](https://platform.openai.com/) (gpt-4.1-nano) or [Ollama](https://ollama.ai/) (qwen3:8b) | — |
| Embeddings | OpenAI text-embedding-3-small or Ollama nomic-embed-text | — |
| Container Runtime | Docker Desktop | 4.62.0 |
| API Framework | FastAPI | >=0.68.0 |

See [docs/environment.md](docs/environment.md) for the complete list.

## License

[MIT](LICENSE)
