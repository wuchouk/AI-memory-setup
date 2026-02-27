# 整合指南：AI 助手透過 REST API

不支援 Model Context Protocol (MCP) 的 AI 工具，可透過 OpenMemory 的 REST API 讀寫記憶。

本指南以 Telegram AI 助手為例，但同樣的方式適用於任何能發 HTTP 請求的工具。

## 運作方式

```
AI 助手  ──curl/HTTP──▶  OpenMemory API (:8765)  ──▶  Qdrant + Ollama
```

與 MCP（提供原生工具整合）不同，REST 存取需要 AI 工具直接執行 curl 或 HTTP 請求。

## API 端點

### 列出記憶

```bash
curl -s "http://localhost:8765/api/v1/memories/?user_id=your-username"
```

回應：
```json
{
  "items": [
    {"id": "...", "content": "偏好 TypeScript 勝過 JavaScript", "created_at": "..."},
    {"id": "...", "content": "所有服務都用 Docker", "created_at": "..."}
  ],
  "total": 42
}
```

### 新增記憶

```bash
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "專案使用 PostgreSQL 16 搭配 pgvector。",
    "user_id": "your-username",
    "agent_id": "your-tool-name"
  }'
```

- `text`: 要處理的內容（mem0 會從中擷取原子事實）
- `user_id`: 你的 OpenMemory 使用者 ID
- `agent_id`: 標識寫入記憶的工具名稱

### 篩選記憶

```bash
curl -s -X POST http://localhost:8765/api/v1/memories/filter \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "your-username"}'
```

> **注意**：REST 的 `filter` 端點只做 metadata 過濾。語意搜尋（向量相似度搜尋）只能透過 MCP 的 `search_memory` 工具使用。

## 設定你的 AI 工具

### 1. 加入 API 指令

在你的 AI 工具配置檔（如 system prompt、AGENTS.md 等）中加入上面的 curl 指令。參考 [config/openclaw-agents-snippet.md](../config/openclaw-agents-snippet.md) 的現成模板。

### 2. 定義寫入規則

告訴 AI 工具何時寫入 OpenMemory：

| 該寫 | 不該寫 |
|------|--------|
| 使用者偏好和習慣 | 臨時 session 細節 |
| 架構決策和原因 | API keys / credentials |
| 重要 bug 和解法 | 一次性 debug session |
| 跨工具需共享的上下文 | 日常小修（typo、formatting） |

### 3. 測試連線

```bash
# 驗證 API 可存取
curl -s http://localhost:8765/docs | head -1

# 寫入測試記憶
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{"text": "測試：REST API 整合正常。", "user_id": "your-username", "agent_id": "test"}'

# 讀取回來
curl -s "http://localhost:8765/api/v1/memories/?user_id=your-username&size=5"
```

## REST vs MCP 功能比較

| 功能 | MCP | REST |
|------|-----|------|
| 語意搜尋 | 有（`search_memory`） | 無（只有 metadata 篩選） |
| 原生工具整合 | 有（顯示為內建工具） | 無（需要執行 curl） |
| 串流 | 有（SSE） | 無 |
| 寫入記憶 | 有 | 有 |
| 列出記憶 | 有 | 有 |
| 刪除記憶 | 有 | 有 |

## Dashboard

你隨時可以在視覺介面瀏覽和管理記憶：
- **Dashboard UI**: http://localhost:3080
- **API 文件**: http://localhost:8765/docs（Swagger UI）
