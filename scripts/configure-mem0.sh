#!/bin/bash
# Configure OpenMemory (mem0) to use local Ollama
#
# Run this AFTER Docker containers are up and BEFORE writing any memories.
# This script sets the LLM, embedder, and vector store configuration,
# then clears any incorrectly-dimensioned Qdrant collections.
#
# Usage:
#   ./configure-mem0.sh                          # Use defaults
#   API_URL=http://myhost:8765 ./configure-mem0.sh  # Custom API URL
#
# Environment variables:
#   API_URL      OpenMemory API URL (default: http://localhost:8765)
#   QDRANT_URL   Qdrant URL (default: http://localhost:6333)
#   LLM_MODEL    Ollama LLM model (default: qwen3:8b)
#   EMBED_MODEL  Ollama embedding model (default: nomic-embed-text:latest)

set -euo pipefail

API="${API_URL:-http://localhost:8765}"
QDRANT="${QDRANT_URL:-http://localhost:6333}"
LLM_MODEL="${LLM_MODEL:-qwen3:8b}"
EMBED_MODEL="${EMBED_MODEL:-nomic-embed-text:latest}"

echo "=== OpenMemory Configuration ==="
echo "API: $API"
echo "Qdrant: $QDRANT"
echo "LLM: $LLM_MODEL"
echo "Embedder: $EMBED_MODEL"
echo ""

# --- 1. Wait for API to be ready ---
echo "⏳ Waiting for API..."
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" "$API/docs" | grep -q 200; then
        echo "✅ API is ready"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "❌ API not responding after 30s. Is Docker running?"
        exit 1
    fi
    sleep 1
done

# --- 2. Configure LLM ---
echo ""
echo "🔧 Setting LLM provider to Ollama ($LLM_MODEL)..."
curl -s -X PUT "$API/api/v1/config/mem0/llm" \
    -H 'Content-Type: application/json' \
    -d "{
        \"provider\": \"ollama\",
        \"config\": {
            \"model\": \"$LLM_MODEL\",
            \"temperature\": 0.1,
            \"max_tokens\": 2000,
            \"ollama_base_url\": \"http://host.docker.internal:11434\"
        }
    }" | python3 -m json.tool 2>/dev/null || true
echo "✅ LLM configured"

# --- 3. Configure Embedder ---
echo ""
echo "🔧 Setting embedder to Ollama ($EMBED_MODEL)..."
curl -s -X PUT "$API/api/v1/config/mem0/embedder" \
    -H 'Content-Type: application/json' \
    -d "{
        \"provider\": \"ollama\",
        \"config\": {
            \"model\": \"$EMBED_MODEL\",
            \"ollama_base_url\": \"http://host.docker.internal:11434\"
        }
    }" | python3 -m json.tool 2>/dev/null || true
echo "✅ Embedder configured"

# --- 4. Configure Vector Store (768 dimensions) ---
echo ""
echo "🔧 Setting vector store to 768 dimensions..."
curl -s -X PUT "$API/api/v1/config/mem0/vector_store" \
    -H 'Content-Type: application/json' \
    -d '{
        "provider": "qdrant",
        "config": {
            "collection_name": "openmemory",
            "host": "mem0_store",
            "port": 6333,
            "embedding_model_dims": 768
        }
    }' | python3 -m json.tool 2>/dev/null || true
echo "✅ Vector store configured"

# --- 5. Delete incorrectly-dimensioned collections ---
echo ""
echo "🗑️  Clearing old Qdrant collections (may have wrong dimensions)..."
curl -s -X DELETE "$QDRANT/collections/openmemory" > /dev/null 2>&1 || true
curl -s -X DELETE "$QDRANT/collections/mem0migrations" > /dev/null 2>&1 || true
echo "✅ Old collections cleared"

# --- 6. Restart API to rebuild with correct dimensions ---
echo ""
echo "🔄 Restarting API container..."
if command -v docker &>/dev/null; then
    docker compose restart openmemory-mcp 2>/dev/null || \
    docker restart openmemory-openmemory-mcp-1 2>/dev/null || \
    echo "⚠️  Could not restart container automatically. Run: docker compose restart openmemory-mcp"
fi

echo "⏳ Waiting for API to restart..."
sleep 8

# --- 7. Verify ---
echo ""
echo "=== Verification ==="
DIMS=$(curl -s "$QDRANT/collections/openmemory" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['config']['params']['vectors']['size'])" 2>/dev/null)
if [ "$DIMS" = "768" ]; then
    echo "✅ Qdrant collection: $DIMS dimensions (correct!)"
else
    echo "❌ Qdrant dimensions: expected 768, got ${DIMS:-unknown}"
    echo "   Try restarting and running this script again."
    exit 1
fi

CONFIG_LLM=$(curl -s "$API/api/v1/config/" | python3 -c "import sys,json; c=json.load(sys.stdin); print(c['mem0']['llm']['provider']+'/'+c['mem0']['llm']['config']['model'])" 2>/dev/null)
echo "LLM: $CONFIG_LLM"

echo ""
echo "✅ Configuration complete! You can now write memories."
echo ""
echo "Quick test:"
echo "  curl -s -X POST $API/api/v1/memories/ \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"text\": \"Test: system deployed successfully.\", \"user_id\": \"your-username\", \"agent_id\": \"test\"}'"
