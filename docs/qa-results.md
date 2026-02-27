# QA Test Results

## Test Framework

The QA suite validates 6 levels of the OpenMemory deployment, from infrastructure health to restart recovery. Each level builds on the previous one.

**Run the full suite:**
```bash
USER_ID=your-username ./scripts/test-qa.sh all
```

**Run a specific level:**
```bash
USER_ID=your-username ./scripts/test-qa.sh level1
```

## Test Levels

### Level 1: Infrastructure

Verifies that all services are running and correctly configured.

| Test | What It Checks | Pass Criteria |
|------|----------------|---------------|
| 1.1 Ollama | Models loaded | >= 2 models (qwen3:8b + nomic-embed-text) |
| 1.2 API | FastAPI endpoint | HTTP 200 on /docs |
| 1.3 Qdrant | Vector dimensions | Collection uses 768 dims |
| 1.4 UI | Dashboard | HTTP 200 on :3080 |
| 1.5 Docker | Restart policy | `restart: always` on API container |
| 1.6 Ollama service | Auto-start | `brew services` shows `started` |
| 1.7 LLM config | Provider | `ollama/qwen3:8b` |

### Level 2: Write Verification

Tests that memories can be written from multiple client identities.

| Test | What It Checks |
|------|----------------|
| 2.1 | Write from client-a (simulates MCP client) |
| 2.2 | Write from client-b (simulates REST client) |

> **Note**: Writes may return `null` if mem0 filters the content as duplicate or non-factual. This is a warning, not a failure.

### Level 3: Cross-Client Read

Verifies that memories written by different clients are accessible from a single user_id.

| Test | What It Checks |
|------|----------------|
| 3.1 | Total memory count > 0 |
| 3.2 | All memories readable from single query |

### Level 4: MCP Connectivity

Tests the MCP (SSE) integration path used by Claude Code.

| Test | What It Checks |
|------|----------------|
| 4.1 | MCP SSE endpoint returns HTTP 200 |
| 4.2 | Claude Code has openmemory registered (optional) |
| 4.3 | Full write+read cycle via API |

### Level 5: REST API

Tests the REST API path used by non-MCP tools.

| Test | What It Checks |
|------|----------------|
| 5.1 | REST write (POST /api/v1/memories/) |
| 5.2 | REST list (GET /api/v1/memories/) |
| 5.3 | REST filter (POST /api/v1/memories/filter) |

### Level 6: Restart Recovery (Manual)

Validates that data persists across a full restart cycle. This test provides instructions for manual execution:

1. Note current memory count
2. Stop everything: `docker compose down && brew services stop ollama`
3. Restart everything: `brew services start ollama && docker compose up -d`
4. Re-run Level 1 tests
5. Verify memory count matches

## Sample Output

```
OpenMemory QA — User: your-username, API: http://localhost:8765

=== Level 1: Infrastructure ===
  ✅ 1.1 Ollama: 2 models loaded
  ✅ 1.2 API: HTTP 200
  ✅ 1.3 Qdrant: 768 dims (correct)
  ✅ 1.4 UI: HTTP 200
  ✅ 1.5 Docker restart: always
  ✅ 1.6 Ollama service: started
  ✅ 1.7 LLM config: ollama/qwen3:8b

=== Level 2: Write Verification ===
  ✅ 2.1 client-a write: "QA Level2 test: client-a can write..."
  ✅ 2.2 client-b write: "QA Level2 test: client-b can write..."

=== Level 3: Cross-Client Read ===
  ✅ 3.1 Total memories: 15
  ✅ 3.2 All 15 memories readable from single user_id

=== Level 4: MCP Connectivity ===
  ✅ 4.1 MCP SSE endpoint: HTTP 200
  ✅ 4.2 Claude Code MCP registered
  ✅ 4.3 Write+read cycle: 16 memories accessible

=== Level 5: REST API ===
  ✅ 5.1 REST write: "REST Level5 test..."
  ✅ 5.2 REST list: 17 memories
  ✅ 5.3 REST filter: 17 memories

=== Level 6: Restart Recovery ===
  (manual steps printed)

Done.
```

## Environment Variables

The QA script is fully configurable via environment variables:

```bash
USER_ID=your-username \
API_URL=http://localhost:8765 \
OLLAMA_URL=http://localhost:11434 \
QDRANT_URL=http://localhost:6333 \
UI_URL=http://localhost:3080 \
./scripts/test-qa.sh all
```
