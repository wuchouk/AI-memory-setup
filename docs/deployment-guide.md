# Deployment Guide

> Step-by-step instructions to deploy OpenMemory (mem0) on macOS with Apple Silicon,
> using Ollama for local LLM inference and Docker for the service stack.

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed
- [Homebrew](https://brew.sh) installed
- At least 16GB RAM (24GB+ recommended)
- ~10GB free disk space (for models + Docker images)

## Phase 1: Install Ollama + Models

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

### Why these models?

- **qwen3:8b**: Excellent multilingual understanding (Chinese + English mixed text). Fact extraction only needs text simplification, not complex reasoning chains. 8B parameters run well on Apple Silicon.
- **nomic-embed-text**: 768-dimension vectors (vs OpenAI's 1536), efficient for local use. Open-source, quality close to OpenAI text-embedding-3-small.

## Phase 2: Deploy the Docker Stack

### 2a. Clone OpenMemory

```bash
cd ~
git clone https://github.com/mem0ai/mem0.git
cd mem0/openmemory
```

### 2b. Create the environment file

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
3. Add `OLLAMA_HOST=http://host.docker.internal:11434` for Docker→host communication
4. Map UI to port `3080` (avoid conflict with dev servers on 3000)

### 2d. Build and Start

```bash
make build
NEXT_PUBLIC_USER_ID=your-username \
NEXT_PUBLIC_API_URL=http://localhost:8765 \
docker compose up -d
```

**Useful Makefile commands**: `make up` / `make down` / `make logs` / `make shell`

### 2e. Configure Ollama as LLM + Embedder

> **This is the most critical step.** Must be done before writing any memories.

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

# Set vector store dimensions to 768
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

The API creates a Qdrant collection with OpenAI's default 1536 dimensions on first start. You must delete and recreate it with the correct 768 dimensions:

```bash
# Delete the wrong-dimension collections
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
  -d '{"text": "Test memory: system deployed successfully.", "user_id": "your-username", "agent_id": "test"}'

# Verify Qdrant dimensions
curl -s http://localhost:6333/collections/openmemory | python3 -c "
import sys, json
d = json.load(sys.stdin)
size = d['result']['config']['params']['vectors']['size']
print(f'Vector size: {size}')
assert size == 768, f'ERROR: expected 768, got {size}'
print('Correct dimensions!')
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
