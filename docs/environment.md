# Environment & Tooling

Complete list of tools, versions, and configurations used in this deployment.

## Hardware

| Component | Specification |
|-----------|--------------|
| Chip | Apple M4 |
| RAM | 24GB unified memory |
| OS | macOS 15.x (Sequoia) |

## Software Stack

### Core Services

| Tool | Version | Role |
|------|---------|------|
| Docker Desktop | 4.62.0 | Container runtime |
| Docker Compose | v5.0.2 | Service orchestration |
| Ollama | 0.17.0 | Local LLM inference |
| Qdrant | v1.17.0 | Vector database |
| mem0 (OpenMemory) | v1.0.4+ (commit 93c72030) | Memory engine |

### AI Models

| Model | Size | Role |
|-------|------|------|
| qwen3:8b | ~5.2GB | Fact extraction (Chinese + English) |
| nomic-embed-text | ~274MB | Vector embeddings (768 dimensions) |

### Runtimes & Frameworks

| Tool | Version | Role |
|------|---------|------|
| Python | 3.9.6+ | API runtime |
| Node.js | v25.x | Dashboard UI runtime |
| FastAPI | >=0.68.0 | API framework |
| mem0ai (Python SDK) | >=0.1.92 | Core memory library |
| MCP SDK | >=1.3.0 | Model Context Protocol |

### Development Tools

| Tool | Version | Role |
|------|---------|------|
| Homebrew | 5.x | macOS package manager |
| gh CLI | 2.x | GitHub operations |
| Claude Code | 2.x | AI coding assistant (MCP client) |

### AI Backend

| Component | Detail |
|-----------|--------|
| LLM Provider | Claude (via Claude Max subscription) |
| Model | Opus 4 |

## Source Repositories

| Repository | Purpose |
|------------|---------|
| [mem0ai/mem0](https://github.com/mem0ai/mem0) | OpenMemory core (cloned and customized) |
| [qdrant/qdrant](https://hub.docker.com/r/qdrant/qdrant) | Vector database Docker image |

## Port Assignments

| Port | Service |
|------|---------|
| 8765 | OpenMemory API (FastAPI) |
| 6333 | Qdrant vector database |
| 3080 | OpenMemory Dashboard UI |
| 11434 | Ollama (LLM inference) |

## Key Configuration Values

| Setting | Value | Why |
|---------|-------|-----|
| Vector dimensions | 768 | Matches nomic-embed-text output |
| LLM temperature | 0.1 | Low randomness for fact extraction |
| LLM max_tokens | 2000 | Sufficient for memory processing |
| Docker restart policy | `always` | Auto-recovery on reboot |
| UI port | 3080 | Avoids conflict with dev servers |
| OLLAMA_HOST | `http://host.docker.internal:11434` | Docker→host communication |
