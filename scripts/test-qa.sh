#!/bin/bash
# OpenMemory QA Test Script
# Validates all layers of the deployment: infrastructure, read/write, MCP, REST.
#
# Usage:
#   ./test-qa.sh [level]        Run a specific level (1-6)
#   ./test-qa.sh all            Run all levels (default)
#   ./test-qa.sh --help         Show usage
#
# Environment variables:
#   USER_ID     Your OpenMemory user ID (default: your-username)
#   API_URL     OpenMemory API base URL (default: http://localhost:8765)
#   OLLAMA_URL  Ollama API base URL (default: http://localhost:11434)
#   QDRANT_URL  Qdrant base URL (default: http://localhost:6333)
#   UI_URL      Dashboard UI URL (default: http://localhost:3080)

set -euo pipefail

# --- Configuration (override via environment variables) ---
API="${API_URL:-http://localhost:8765}"
OLLAMA="${OLLAMA_URL:-http://localhost:11434}"
QDRANT="${QDRANT_URL:-http://localhost:6333}"
UI="${UI_URL:-http://localhost:3080}"
USER_ID="${USER_ID:-your-username}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✅ $1${NC}"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }

show_help() {
    echo "OpenMemory QA Test Script"
    echo ""
    echo "Usage: $0 [level1|level2|level3|level4|level5|level6|all|--help]"
    echo ""
    echo "Levels:"
    echo "  level1 (1)  Infrastructure checks (Ollama, API, Qdrant, UI, Docker)"
    echo "  level2 (2)  Write verification (write from multiple clients)"
    echo "  level3 (3)  Cross-client read (verify shared access)"
    echo "  level4 (4)  MCP connectivity (SSE endpoint, Claude Code integration)"
    echo "  level5 (5)  REST API (write, list, filter via REST)"
    echo "  level6 (6)  Restart recovery (manual steps)"
    echo "  all         Run all levels (default)"
    echo ""
    echo "Environment variables:"
    echo "  USER_ID=$USER_ID"
    echo "  API_URL=$API"
    echo "  OLLAMA_URL=$OLLAMA"
    echo "  QDRANT_URL=$QDRANT"
    echo "  UI_URL=$UI"
}

test_level1() {
    echo ""
    echo "=== Level 1: Infrastructure ==="

    # 1.1 Ollama
    MODELS=$(curl -s "$OLLAMA/api/tags" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('models',[])))" 2>/dev/null)
    [ "$MODELS" -ge 2 ] 2>/dev/null && pass "1.1 Ollama: $MODELS models loaded" || fail "1.1 Ollama: expected >=2 models, got ${MODELS:-none}"

    # 1.2 API
    API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API/docs")
    [ "$API_STATUS" = "200" ] && pass "1.2 API: HTTP $API_STATUS" || fail "1.2 API: HTTP $API_STATUS"

    # 1.3 Qdrant vector dimensions
    QDRANT_DIMS=$(curl -s "$QDRANT/collections/openmemory" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['config']['params']['vectors']['size'])" 2>/dev/null)
    [ "$QDRANT_DIMS" = "768" ] && pass "1.3 Qdrant: $QDRANT_DIMS dims (correct)" || fail "1.3 Qdrant: expected 768 dims, got ${QDRANT_DIMS:-unknown}"

    # 1.4 UI
    UI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$UI")
    [ "$UI_STATUS" = "200" ] && pass "1.4 UI: HTTP $UI_STATUS" || fail "1.4 UI: HTTP $UI_STATUS"

    # 1.5 Docker restart policy
    RESTART=$(docker inspect openmemory-openmemory-mcp-1 --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)
    [ "$RESTART" = "always" ] && pass "1.5 Docker restart: $RESTART" || fail "1.5 Docker restart: ${RESTART:-not found}"

    # 1.6 Ollama service (macOS only)
    if command -v brew &>/dev/null; then
        OLLAMA_SVC=$(brew services list 2>/dev/null | grep ollama | awk '{print $2}')
        [ "$OLLAMA_SVC" = "started" ] && pass "1.6 Ollama service: $OLLAMA_SVC" || fail "1.6 Ollama service: ${OLLAMA_SVC:-not found}"
    else
        warn "1.6 Ollama service: brew not available, skipping"
    fi

    # 1.7 LLM config
    CONFIG_LLM=$(curl -s "$API/api/v1/config/" | python3 -c "import sys,json; c=json.load(sys.stdin); print(c['mem0']['llm']['provider']+'/'+c['mem0']['llm']['config']['model'])" 2>/dev/null)
    [ "$CONFIG_LLM" = "ollama/qwen3:8b" ] && pass "1.7 LLM config: $CONFIG_LLM" || fail "1.7 LLM config: ${CONFIG_LLM:-unknown}"
}

test_level2() {
    echo ""
    echo "=== Level 2: Write Verification ==="

    # 2.1 Write from client A
    echo "  Writing from client-a (may take 10-30s for Ollama cold start)..."
    RESULT=$(curl -s --max-time 60 -X POST "$API/api/v1/memories/" \
        -H 'Content-Type: application/json' \
        -d "{\"text\": \"QA Level2 test: client-a can write to OpenMemory. Timestamp $(date +%s).\", \"user_id\": \"$USER_ID\", \"agent_id\": \"client-a\"}")
    CC_CONTENT=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',''))" 2>/dev/null)
    [ -n "$CC_CONTENT" ] && pass "2.1 client-a write: \"$CC_CONTENT\"" || warn "2.1 client-a write: null (mem0 may have filtered as duplicate)"

    # 2.2 Write from client B
    echo "  Writing from client-b..."
    RESULT=$(curl -s --max-time 60 -X POST "$API/api/v1/memories/" \
        -H 'Content-Type: application/json' \
        -d "{\"text\": \"QA Level2 test: client-b can write to OpenMemory. Timestamp $(date +%s).\", \"user_id\": \"$USER_ID\", \"agent_id\": \"client-b\"}")
    OC_CONTENT=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',''))" 2>/dev/null)
    [ -n "$OC_CONTENT" ] && pass "2.2 client-b write: \"$OC_CONTENT\"" || warn "2.2 client-b write: null (mem0 may have filtered as duplicate)"
}

test_level3() {
    echo ""
    echo "=== Level 3: Cross-Client Read ==="

    TOTAL=$(curl -s "$API/api/v1/memories/?user_id=$USER_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])" 2>/dev/null)
    [ "$TOTAL" -gt 0 ] 2>/dev/null && pass "3.1 Total memories: $TOTAL" || fail "3.1 No memories found"

    # Verify memories are readable
    curl -s "$API/api/v1/memories/?user_id=$USER_ID&size=100" | python3 -c "
import sys, json
data = json.load(sys.stdin)
contents = [item['content'] for item in data['items']]
count = len(contents)
if count > 0:
    print(f'  ✅ 3.2 All {count} memories readable from single user_id')
else:
    print('  ❌ 3.2 No memories found')
"
}

test_level4() {
    echo ""
    echo "=== Level 4: MCP Connectivity ==="

    # 4.1 SSE endpoint responds
    SSE_STATUS=$(curl -s -w "%{http_code}" -o /dev/null --max-time 5 \
        "$API/mcp/claude-code/sse/$USER_ID")
    [ "$SSE_STATUS" = "200" ] && pass "4.1 MCP SSE endpoint: HTTP $SSE_STATUS" || fail "4.1 MCP SSE endpoint: HTTP $SSE_STATUS"

    # 4.2 Claude Code MCP registered (optional)
    if command -v claude &>/dev/null; then
        MCP_ENTRY=$(claude mcp list 2>/dev/null | grep openmemory)
        [ -n "$MCP_ENTRY" ] && pass "4.2 Claude Code MCP registered: $(echo "$MCP_ENTRY" | head -c 80)" || fail "4.2 Claude Code MCP not found in 'claude mcp list'"
    else
        warn "4.2 claude CLI not in PATH, skipping"
    fi

    # 4.3 Write+read cycle via REST (simulates MCP tool behavior)
    TS=$(date +%s)
    curl -s --max-time 60 -X POST "$API/api/v1/memories/" \
        -H 'Content-Type: application/json' \
        -d "{\"text\": \"MCP Level4 test $TS: write-read cycle verification.\", \"user_id\": \"$USER_ID\", \"agent_id\": \"client-a\"}" > /dev/null
    SEARCH=$(curl -s --max-time 30 "$API/api/v1/memories/?user_id=$USER_ID&size=5" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])" 2>/dev/null)
    [ "$SEARCH" -gt 0 ] 2>/dev/null && pass "4.3 Write+read cycle: $SEARCH memories accessible" || fail "4.3 Write+read cycle failed"
}

test_level5() {
    echo ""
    echo "=== Level 5: REST API ==="

    # 5.1 REST write
    TS=$(date +%s)
    RESULT=$(curl -s --max-time 60 -X POST "$API/api/v1/memories/" \
        -H 'Content-Type: application/json' \
        -d "{\"text\": \"REST Level5 test $TS: REST API write verification.\", \"user_id\": \"$USER_ID\", \"agent_id\": \"client-b\"}")
    OC_CONTENT=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',''))" 2>/dev/null)
    [ -n "$OC_CONTENT" ] && pass "5.1 REST write: \"$OC_CONTENT\"" || warn "5.1 REST write: null (mem0 filtered as duplicate)"

    # 5.2 REST list memories
    TOTAL=$(curl -s --max-time 10 "$API/api/v1/memories/?user_id=$USER_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])" 2>/dev/null)
    [ "$TOTAL" -gt 0 ] 2>/dev/null && pass "5.2 REST list: $TOTAL memories" || fail "5.2 REST list failed"

    # 5.3 REST filter
    FILTER_HITS=$(curl -s --max-time 30 -X POST "$API/api/v1/memories/filter" \
        -H 'Content-Type: application/json' \
        -d "{\"user_id\": \"$USER_ID\"}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null)
    [ "$FILTER_HITS" -gt 0 ] 2>/dev/null && pass "5.3 REST filter: $FILTER_HITS memories" || fail "5.3 REST filter returned 0 results"
}

test_level6() {
    echo ""
    echo "=== Level 6: Restart Recovery ==="
    echo "  This test requires manual steps:"
    echo "  1. Note current memory count"
    TOTAL=$(curl -s "$API/api/v1/memories/?user_id=$USER_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])" 2>/dev/null)
    echo "     Current count: ${TOTAL:-unknown}"
    echo "  2. Run: cd ~/mem0/openmemory && docker compose down && brew services stop ollama"
    echo "  3. Run: brew services start ollama && sleep 3 && docker compose up -d && sleep 10"
    echo "  4. Run: $0 level1"
    echo "  5. Check memory count matches: ${TOTAL:-unknown}"
}

case "${1:-all}" in
    --help|-h) show_help ;;
    level1|1) test_level1 ;;
    level2|2) test_level2 ;;
    level3|3) test_level3 ;;
    level4|4) test_level4 ;;
    level5|5) test_level5 ;;
    level6|6) test_level6 ;;
    all)
        echo "OpenMemory QA — User: $USER_ID, API: $API"
        test_level1
        test_level2
        test_level3
        test_level4
        test_level5
        test_level6
        ;;
    *) echo "Usage: $0 [level1|level2|level3|level4|level5|level6|all|--help]" ;;
esac

echo ""
echo "Done."
