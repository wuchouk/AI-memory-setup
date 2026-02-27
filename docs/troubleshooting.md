# Troubleshooting

The top 5 issues encountered during deployment — and how to fix them.

## 1. Qdrant Dimension Mismatch (Most Common)

**Symptom**: `shapes (0,1536) and (768,) not aligned`

**Cause**: The API initializes with OpenAI's default config on first start, creating a Qdrant collection with 1536 dimensions. But nomic-embed-text produces 768-dimensional vectors.

**Fix** — all three steps are required:

```bash
# 1. Set embedding_model_dims to 768 via Config API
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

# 2. Delete the existing collections
curl -X DELETE http://localhost:6333/collections/openmemory
curl -X DELETE http://localhost:6333/collections/mem0migrations

# 3. Restart the API container
docker compose restart openmemory-mcp
sleep 8
```

**Verify**:
```bash
curl -s http://localhost:6333/collections/openmemory | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['result']['config']['params']['vectors']['size'])"
# Should print: 768
```

## 2. Docker USER Environment Variable

**Symptom**: `User not found` when writing memories

**Cause**: Using `environment: - USER` in docker-compose.yml inherits the host machine's `$USER` variable, which may differ from your OpenMemory username.

**Fix**: Hardcode the username in docker-compose.yml:
```yaml
environment:
  - USER=your-username    # Hardcode this — do NOT use '- USER'
```

## 3. mem0 Returns Null

**Symptom**: POST to `/api/v1/memories/` returns `null` with HTTP 200

**Cause**: mem0 determines the input text contains no new facts worth extracting (may be duplicate of existing memory, or not a factual statement).

**This is normal behavior.** mem0 only stores information it considers "new and factual." Try writing something more specific:

```bash
# Too vague (may return null):
curl ... -d '{"text": "test", ...}'

# Better (contains extractable facts):
curl ... -d '{"text": "The project uses PostgreSQL 16 with pgvector for embeddings.", ...}'
```

## 4. Categorization 401 Error

**Symptom**: API logs show `Failed to get categories: Error code: 401`

**Cause**: The memory categorization feature attempts to call OpenAI's API (the API key is set to `not-needed`). Categorization failure does not affect core memory read/write.

**Fix**: Safe to ignore. Categorization is a non-critical feature. Core memory operations work fine without it.

## 5. Slow Write Speed (10-30 seconds)

**Symptom**: Each memory write takes 10-30 seconds

**Cause**: Every write runs Ollama inference (fact extraction + embedding). The first write is slowest because Ollama needs to load the model into RAM.

**This is expected behavior.** Ollama automatically unloads models after idle time. Subsequent writes are faster once the model is loaded.

**Mitigation**:
- First write in a session will always be slow (~20-30s for model loading)
- Subsequent writes are faster (~5-15s)
- If too slow, consider a smaller model like `qwen3:4b` (saves ~3GB RAM, faster inference)

## FAQ

### Q: Can I use a different LLM instead of qwen3:8b?

Yes. Any Ollama model works. Update the config:
```bash
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/llm \
  -H 'Content-Type: application/json' \
  -d '{"provider": "ollama", "config": {"model": "your-model-name", ...}}'
```

Good alternatives:
- `qwen3:4b` — smaller, faster, uses less RAM
- `llama3.1:8b` — strong for English-only use cases
- `gemma2:9b` — Google's model, good multilingual support

### Q: Can I use a different embedding model?

Yes, but you must also update `embedding_model_dims` in the vector store config to match the model's output dimensions, then delete and recreate the Qdrant collection. See [Issue #1](#1-qdrant-dimension-mismatch-most-common) above.

### Q: How do I back up my memories?

Export a Qdrant snapshot:
```bash
curl -X POST http://localhost:6333/collections/openmemory/snapshots
```

Or back up the Docker volume directly:
```bash
docker run --rm -v mem0_storage:/data -v $(pwd):/backup \
  alpine tar czf /backup/qdrant-backup.tar.gz /data
```

### Q: How do I reset everything and start fresh?

```bash
# Stop all services
cd ~/mem0/openmemory && docker compose down

# Delete Qdrant data
docker volume rm openmemory_mem0_storage

# Restart
docker compose up -d

# Reconfigure (essential!)
./scripts/configure-mem0.sh
```

### Q: The MCP connection works initially but drops after a while?

MCP connects only at Claude Code session startup. If Docker restarts while Claude Code is running, the connection is lost. Solution: restart your Claude Code session.
