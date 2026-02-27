#!/bin/bash
# Setup Ollama with required models for OpenMemory
#
# This script installs Ollama (if not present), enables auto-start,
# and pulls the required LLM and embedding models.
#
# Usage: ./setup-ollama.sh

set -euo pipefail

echo "=== Ollama Setup for OpenMemory ==="
echo ""

# --- 1. Install Ollama ---
if command -v ollama &>/dev/null; then
    echo "✅ Ollama already installed: $(ollama --version 2>/dev/null || echo 'unknown version')"
else
    echo "📦 Installing Ollama via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew not found. Install from https://brew.sh first."
        exit 1
    fi
    brew install ollama
    echo "✅ Ollama installed"
fi

# --- 2. Enable auto-start ---
echo ""
echo "🔄 Enabling Ollama auto-start (brew services)..."
brew services start ollama 2>/dev/null || true
sleep 3

# Verify Ollama is running
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama is running"
else
    echo "❌ Ollama not responding. Check: brew services list"
    exit 1
fi

# --- 3. Pull models ---
echo ""
echo "📥 Pulling LLM model: qwen3:8b (~5.2GB)..."
echo "   (This may take a while on first download)"
ollama pull qwen3:8b

echo ""
echo "📥 Pulling embedding model: nomic-embed-text (~274MB)..."
ollama pull nomic-embed-text

# --- 4. Verify ---
echo ""
echo "=== Verification ==="
MODELS=$(ollama list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
echo "Models installed: $MODELS"
ollama list
echo ""

if [ "$MODELS" -ge 2 ]; then
    echo "✅ Ollama setup complete!"
    echo ""
    echo "Models ready:"
    echo "  - qwen3:8b         → Fact extraction LLM (Chinese + English)"
    echo "  - nomic-embed-text → Vector embeddings (768 dimensions)"
else
    echo "⚠️  Expected at least 2 models. Please check 'ollama list'."
fi
