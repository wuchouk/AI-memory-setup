# 部署指南

> 在 macOS Apple Silicon 上部署 OpenMemory (mem0) 的完整步驟。
> 兩種 LLM 供應商選項：**OpenAI API**（推薦）或**本機 Ollama**。

## 選擇你的 LLM 供應商

| | OpenAI API（推薦） | Ollama（本機） |
|---|---|---|
| **費用** | 約 $0.17/月 | 免費 |
| **寫入速度** | ~5-7 秒 | ~25 秒 |
| **中文準確度** | 優秀 | 不穩定（混合格式約 50% 失敗） |
| **RAM 用量** | 0（雲端） | ~7GB |
| **隱私** | 資料傳送至 OpenAI | 完全本機 |
| **自動分類** | 有 | 無（硬編碼 OpenAI 依賴） |

> **為什麼推薦 OpenAI**：Ollama 的本機模型（測試過 qwen3:8b）在處理中英文夾雜的事實擷取時表現不穩，結構化格式如 `[開發教訓]` 的失敗率約 50%。OpenAI gpt-4.1-nano 更快、更可靠，每月費用不到 $0.20。詳見 [Issue #1](https://github.com/wuchouk/AI-memory-setup/issues/1)。

## 前置條件

- macOS Apple Silicon（M1/M2/M3/M4）
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) 已安裝
- [Homebrew](https://brew.sh) 已安裝
- **OpenAI 路線**：一組 OpenAI API key
- **Ollama 路線**：至少 16GB RAM（建議 24GB+），約 10GB 可用磁碟空間

## Phase 1: LLM 設定

### 選項 A：OpenAI API（推薦）

不需要安裝本機模型，只要準備好 OpenAI API key 即可。

### 選項 B：Ollama（本機）

```bash
# 安裝 Ollama
brew install ollama

# 啟用開機自啟（Launch Agent）
brew services start ollama

# 拉取事實擷取 LLM（~5.2GB）
ollama pull qwen3:8b

# 拉取向量嵌入模型（~274MB）
ollama pull nomic-embed-text

# 驗證兩個模型已安裝
ollama list
```

或使用 helper 腳本：
```bash
./scripts/setup-ollama.sh
```

<details>
<summary>為什麼選這些 Ollama 模型？</summary>

- **qwen3:8b**：中英文夾雜理解能力佳。記憶擷取只需文字簡化和事實提取，不需要推理鏈。8B 參數在 Apple Silicon 上推理速度合理。
- **nomic-embed-text**：768 維度向量，開源，品質接近 OpenAI text-embedding-3-small。

**已知限制**：處理中文結構化格式（如 `[開發教訓]` 標籤）不穩定。詳見疑難排解。
</details>

## Phase 2: 部署 Docker 堆疊

### 2a. Clone OpenMemory

```bash
cd ~
git clone https://github.com/mem0ai/mem0.git
cd mem0/openmemory
```

### 2b. 建立環境設定檔

**OpenAI 路線**：
```bash
cat > api/.env << 'EOF'
USER=your-username
OPENAI_API_KEY=sk-proj-your-key-here
EOF
```

**Ollama 路線**：
```bash
cat > api/.env << 'EOF'
USER=your-username
OPENAI_API_KEY=not-needed
OLLAMA_HOST=http://host.docker.internal:11434
EOF
```

### 2c. 修改 docker-compose.yml

套用以下關鍵改動（或參考 [config/docker-compose.yml](../config/docker-compose.yml)）：

1. 所有服務加上 `restart: always`（重啟自恢復）
2. API 環境寫死 `USER=your-username`（不要用 `- USER`）
3. **僅 Ollama**：加上 `OLLAMA_HOST=http://host.docker.internal:11434`（Docker 連主機）
4. UI 映射到 port `3080`（避免與開發伺服器的 3000 衝突）

### 2d. Build 和啟動

```bash
make build
NEXT_PUBLIC_USER_ID=your-username \
NEXT_PUBLIC_API_URL=http://localhost:8765 \
docker compose up -d
```

**Makefile 快速指令**：`make up` / `make down` / `make logs` / `make shell`

### 2e. 設定 LLM + Embedder

> **這是最關鍵的步驟。** 必須在寫入任何記憶之前完成。

#### 選項 A：OpenAI（推薦）

```bash
# 設定 LLM
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

# 設定 Embedder
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/embedder \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "openai",
    "config": {
      "model": "text-embedding-3-small",
      "api_key": "env:OPENAI_API_KEY"
    }
  }'

# 設定 Vector Store 維度為 1536（對應 text-embedding-3-small）
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

> **重要**：`max_tokens` 至少要 2000（建議 4096）。數值太低會導致 mem0 在比對大量現有記憶時靜默失敗。詳見[疑難排解](troubleshooting.zh-TW.md#6-silent-null-returns-with-openai-max_tokens-too-low)。

#### 選項 B：Ollama（本機）

```bash
# 設定 LLM
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

# 設定 Embedder
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/embedder \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "ollama",
    "config": {
      "model": "nomic-embed-text:latest",
      "ollama_base_url": "http://host.docker.internal:11434"
    }
  }'

# 設定 Vector Store 維度為 768（對應 nomic-embed-text）
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

或使用 helper 腳本：
```bash
./scripts/configure-mem0.sh
```

### 2f. 清除錯誤維度的 Collection

API 啟動時可能會用錯誤的維度建立 Qdrant collection。刪除後讓它用正確的配置重建：

```bash
curl -X DELETE http://localhost:6333/collections/openmemory
curl -X DELETE http://localhost:6333/collections/mem0migrations

# 重啟 API 讓 memory client 用新 config 重建
docker compose restart openmemory-mcp
sleep 8
```

### 2g. 驗證

```bash
# 寫入測試記憶
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test memory: system deployed successfully.", "user_id": "your-username"}'

# 確認 Qdrant 維度（OpenAI 為 1536，Ollama 為 768）
curl -s http://localhost:6333/collections/openmemory | python3 -c "
import sys, json
d = json.load(sys.stdin)
size = d['result']['config']['params']['vectors']['size']
print(f'Vector size: {size}')
print('維度正確！' if size in (768, 1536) else 'ERROR: unexpected size')
"
```

## Phase 3: 接入 Claude Code (MCP)

```bash
# 加入 MCP server（user scope = 全局可用）
claude mcp add -s user openmemory --transport sse \
  http://localhost:8765/mcp/claude-code/sse/your-username
```

在 `~/.claude/CLAUDE.md` 加入使用指引——見 [config/claude-md-snippet.md](../config/claude-md-snippet.md)。

**驗證 MCP 連線**：
```bash
claude mcp list
# 應顯示：openmemory: ... ✓ Connected
```

若顯示 `✗ Failed to connect`：
1. 確認 Docker 容器在跑：`docker ps | grep openmemory`
2. 確認 API 端點可用：`curl -s http://localhost:8765/docs`
3. 重啟 Claude Code session（MCP 只在 session 啟動時連線）

## Phase 4: 接入其他 AI 工具 (REST API)

不支援 MCP 的工具，直接用 REST API：

```bash
# 列出記憶
curl -s "http://localhost:8765/api/v1/memories/?user_id=your-username"

# 新增記憶
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{"text": "要記住的內容", "user_id": "your-username", "agent_id": "your-tool-name"}'

# 篩選記憶
curl -s -X POST http://localhost:8765/api/v1/memories/filter \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "your-username"}'
```

參考 [config/openclaw-agents-snippet.md](../config/openclaw-agents-snippet.md) 的現成配置片段。

> **注意**：語意搜尋（`search_memory`）只能透過 MCP 使用。REST 的 `filter` 做的是 metadata 過濾，不是向量相似度搜尋。

## 關鍵端點

| 端點 | 用途 |
|------|------|
| http://localhost:8765/docs | API 文件（Swagger UI） |
| http://localhost:8765/api/v1/memories/?user_id=your-username | 列出記憶 |
| http://localhost:8765/api/v1/config/ | 查看/修改配置 |
| http://localhost:6333/dashboard | Qdrant Dashboard |
| http://localhost:3080 | OpenMemory Dashboard UI |

## 下一步

- 執行 [QA 測試套件](qa-results.zh-TW.md) 驗證部署
- 查看[疑難排解](troubleshooting.zh-TW.md)處理常見問題
- 設定 AI 工具的[記憶寫入指引](../config/claude-md-snippet.md)
