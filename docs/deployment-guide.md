# Deployment Guide

> Step-by-step instructions to deploy OpenMemory (mem0) on macOS with Apple Silicon.
> Two LLM provider options: **OpenAI API** (recommended) or **local Ollama**.

## Choose Your LLM Provider

| | OpenAI API (Recommended) | Ollama (Local) |
|---|---|---|
| **Cost** | ~$0.17/month | Free |
| **Write speed** | ~5-7s | ~25s |
| **Chinese accuracy** | Excellent | Inconsistent (~50% for mixed format) |
| **RAM usage** | 0 (cloud) | ~7GB |
| **Privacy** | Data sent to OpenAI | Fully local |
| **Auto-categorization** | Yes | No (hardcoded OpenAI dependency) |

> **Why we recommend OpenAI**: Ollama's local models (tested: qwen3:8b) struggle with Chinese+English mixed text fact extraction, producing ~50% failure rates on structured formats like `[開發教訓]`. OpenAI gpt-4.1-nano is faster, more reliable, and costs under $0.20/month. See [Issue #1](https://github.com/wuchouk/AI-memory-setup/issues/1) for details.

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed
- [Homebrew](https://brew.sh) installed
- **OpenAI path**: An OpenAI API key
- **Ollama path**: At least 16GB RAM (24GB+ recommended), ~10GB free disk space

## Phase 1: LLM Setup

### Option A: OpenAI API (Recommended)

No local model installation needed. Just have your OpenAI API key ready.

### Option B: Ollama (Local)

```bash
# Install Ollama
brew install ollama

# Enable auto-start on boot (Launch Agent)
brew services start ollama

# Pull the LLM for fact extraction (~5.2GB)
ollama pull qwen3:8b

# Pull the embedding model (~274MB)
ollama pull nomic-embed-text

# Verify both models are installed
ollama list
```

Or use the helper script:
```bash
./scripts/setup-ollama.sh
```

<details>
<summary>Why these Ollama models?</summary>

- **qwen3:8b**: Multilingual understanding (Chinese + English). Fact extraction only needs text simplification, not complex reasoning. 8B parameters run on Apple Silicon.
- **nomic-embed-text**: 768-dimension vectors, open-source, quality close to OpenAI text-embedding-3-small.

**Known limitations**: Unstable with Chinese structured formats (e.g., `[開發教訓]` tags). See troubleshooting for details.
</details>

## Phase 2: Deploy the Docker Stack

### 2a. Clone OpenMemory

```bash
cd ~
git clone https://github.com/mem0ai/mem0.git
cd mem0/openmemory
```

### 2b. Create the environment file

**OpenAI path**:
```bash
cat > api/.env << 'EOF'
USER=your-username
OPENAI_API_KEY=sk-proj-your-key-here
EOF
```

**Ollama path**:
```bash
cat > api/.env << 'EOF'
USER=your-username
OPENAI_API_KEY=not-needed
OLLAMA_HOST=http://host.docker.internal:11434
EOF
```

### 2c. Customize docker-compose.yml

Apply these key modifications (or use [config/docker-compose.yml](../config/docker-compose.yml) as reference):

1. Add `restart: always` to all services (auto-recovery on reboot)
2. Hardcode `USER=your-username` in the API environment (don't use `- USER`)
3. **Ollama only**: Add `OLLAMA_HOST=http://host.docker.internal:11434` for Docker→host communication
4. Map UI to port `3080` (avoid conflict with dev servers on 3000)

### 2d. Build and Start

```bash
make build
NEXT_PUBLIC_USER_ID=your-username \
NEXT_PUBLIC_API_URL=http://localhost:8765 \
docker compose up -d
```

**Useful Makefile commands**: `make up` / `make down` / `make logs` / `make shell`

### 2e. Configure LLM + Embedder

> **This is the most critical step.** Must be done before writing any memories.

#### Option A: OpenAI (Recommended)

```bash
# Set LLM provider
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/llm \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "openai",
    "config": {
      "model": "gpt-4.1-nano",
      "temperature": 0.1,
      "max_tokens": 4096,
      "api_key": "env:OPENAI_API_KEY"
    }
  }'

# Set embedding provider
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/embedder \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "openai",
    "config": {
      "model": "text-embedding-3-small",
      "api_key": "env:OPENAI_API_KEY"
    }
  }'

# Set vector store dimensions to 1536 (matches text-embedding-3-small)
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/vector_store \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "qdrant",
    "config": {
      "collection_name": "openmemory",
      "host": "mem0_store",
      "port": 6333,
      "embedding_model_dims": 1536
    }
  }'
```

> **Important**: `max_tokens` must be at least 2000 (4096 recommended). Lower values cause silent failures when mem0 compares against many existing memories. See [troubleshooting](troubleshooting.md#6-silent-null-returns-with-openai-max_tokens-too-low).

#### Option B: Ollama (Local)

```bash
# Set LLM provider
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/llm \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "ollama",
    "config": {
      "model": "qwen3:8b",
      "temperature": 0.1,
      "max_tokens": 2000,
      "ollama_base_url": "http://host.docker.internal:11434"
    }
  }'

# Set embedding provider
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/embedder \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "ollama",
    "config": {
      "model": "nomic-embed-text:latest",
      "ollama_base_url": "http://host.docker.internal:11434"
    }
  }'

# Set vector store dimensions to 768 (matches nomic-embed-text)
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/vector_store \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "qdrant",
    "config": {
      "collection_name": "openmemory",
      "host": "mem0_store",
      "port": 6333,
      "embedding_model_dims": 768
    }
  }'
```

Or use the helper script:
```bash
./scripts/configure-mem0.sh
```

### 2f. Clear Incorrectly-Dimensioned Collections

The API may create a Qdrant collection with the wrong dimensions on first start. Delete and let it recreate with the correct config:

```bash
curl -X DELETE http://localhost:6333/collections/openmemory
curl -X DELETE http://localhost:6333/collections/mem0migrations

# Restart API to rebuild with correct config
docker compose restart openmemory-mcp
sleep 8
```

### 2g. Verify

```bash
# Write a test memory
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test memory: system deployed successfully.", "user_id": "your-username"}'

# Verify Qdrant dimensions (1536 for OpenAI, 768 for Ollama)
curl -s http://localhost:6333/collections/openmemory | python3 -c "
import sys, json
d = json.load(sys.stdin)
size = d['result']['config']['params']['vectors']['size']
print(f'Vector size: {size}')
print('Correct!' if size in (768, 1536) else 'ERROR: unexpected size')
"
```

## Phase 3: Connect Claude Code (MCP)

```bash
# Register the MCP server (user scope = globally available)
claude mcp add -s user openmemory --transport sse \
  http://localhost:8765/mcp/claude-code/sse/your-username
```

Add usage instructions to `~/.claude/CLAUDE.md` — see [config/claude-md-snippet.md](../config/claude-md-snippet.md).

**Verify MCP connection**:
```bash
claude mcp list
# Should show: openmemory: ... ✓ Connected
```

If it shows `✗ Failed to connect`:
1. Check Docker containers are running: `docker ps | grep openmemory`
2. Check API endpoint: `curl -s http://localhost:8765/docs`
3. Restart Claude Code session (MCP connects only at session startup)

## Phase 4: Connect Other AI Tools (REST API)

For tools that don't support MCP, use the REST API directly:

```bash
# List memories
curl -s "http://localhost:8765/api/v1/memories/?user_id=your-username"

# Add a memory
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{"text": "Content to remember", "user_id": "your-username", "agent_id": "your-tool-name"}'

# Filter memories
curl -s -X POST http://localhost:8765/api/v1/memories/filter \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "your-username"}'
```

See [config/openclaw-agents-snippet.md](../config/openclaw-agents-snippet.md) for a ready-to-use configuration snippet.

> **Note**: Semantic search (`search_memory`) is only available via MCP. The REST `filter` endpoint does metadata filtering, not vector similarity search.

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| http://localhost:8765/docs | API documentation (Swagger UI) |
| http://localhost:8765/api/v1/memories/?user_id=your-username | List memories |
| http://localhost:8765/api/v1/config/ | View/modify configuration |
| http://localhost:6333/dashboard | Qdrant Dashboard |
| http://localhost:3080 | OpenMemory Dashboard UI |

## Next Steps

- Run the [QA test suite](qa-results.md) to validate your deployment
- Review [troubleshooting](troubleshooting.md) for common issues
- Set up [memory write guidelines](../config/claude-md-snippet.md) for your AI tools
