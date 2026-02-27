# 整合指南：Claude Code (MCP)

Claude Code 支援 [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)，提供與 OpenMemory 的原生工具級整合。

## 運作方式

Claude Code 透過 Server-Sent Events (SSE) 連接 OpenMemory。註冊後，AI 助手可以將 `search_memory` 和 `add_memories` 作為內建工具使用——不需要 curl 指令。

```
Claude Code  ──SSE──▶  OpenMemory API (:8765)  ──▶  Qdrant + Ollama
```

## 設定

### 1. 註冊 MCP Server

```bash
claude mcp add -s user openmemory --transport sse \
  http://localhost:8765/mcp/claude-code/sse/your-username
```

- `-s user`: User 級別作用域（跨所有專案可用）
- `--transport sse`: Server-Sent Events 協定
- 將 `your-username` 替換為你的 OpenMemory 使用者 ID

### 2. 驗證連線

```bash
claude mcp list
```

預期輸出：
```
openmemory: http://localhost:8765/mcp/claude-code/sse/your-username ✓ Connected
```

### 3. 在 CLAUDE.md 加入指引

將 [config/claude-md-snippet.md](../config/claude-md-snippet.md) 的內容複製到你的 `~/.claude/CLAUDE.md`。這會告訴 Claude Code：

- **何時**讀寫記憶（里程碑驅動的觸發時機）
- **什麼**該存（穩定事實，非 session 細節）
- **什麼**不存（機密資訊、臨時資訊、小修改）

## 可用的 MCP 工具

連線後，Claude Code 可使用這些工具：

| 工具 | 說明 |
|------|------|
| `search_memory` | 跨所有記憶的語意搜尋 |
| `add_memories` | 寫入新事實到記憶庫 |
| `list_memories` | 列出記憶（可選篩選） |
| `delete_memories` | 刪除特定記憶 |

## 使用範例

在 Claude Code session 中，AI 會自動：

```
# 開始新任務時：
「讓我先查一下 OpenMemory 有沒有相關背景...」
→ search_memory("專案架構偏好")

# 做出重要決策後：
「我把這個存到 OpenMemory，其他工具也能查到...」
→ add_memories("專案的公開 API 從 REST 換成了 GraphQL")
```

## 疑難排解

### 啟動時連線失敗

1. 確認 Docker 在跑：`docker ps | grep openmemory`
2. 直接測試 API：`curl -s http://localhost:8765/docs`
3. 測試 SSE 端點：`curl -s http://localhost:8765/mcp/claude-code/sse/your-username`
4. 重啟 Claude Code（MCP 只在 session 啟動時連線）

### 工具列表中看不到 "openmemory"

- 檢查註冊狀態：`claude mcp list`
- 需要時重新註冊：`claude mcp remove openmemory && claude mcp add ...`
- 重啟 Claude Code session

### 連線正常但工具很慢

這是正常的——每次記憶寫入需要 Ollama 推理（10-30 秒）。參見[疑難排解](troubleshooting.zh-TW.md#5-寫入速度慢10-30-秒)。

## 設定參考

MCP 設定檔位置：`~/.claude/mcp_servers.json`

範例：
```json
{
  "openmemory": {
    "type": "sse",
    "url": "http://localhost:8765/mcp/claude-code/sse/your-username"
  }
}
```

## 選配：Claude Desktop 整合

Claude Desktop 也支援 MCP，可以連接同一個 OpenMemory 實例。這讓你在 Chat、Cowork、Code 三種模式都能存取共享記憶。

> **注意**：Claude Desktop 不支援直接使用 SSE URL。需要 `mcp-remote` 作為橋接。

### 設定方式

1. 確認 `npx` 可用（沒有的話：`npm install -g npx`）
2. 編輯 `~/Library/Application Support/Claude/claude_desktop_config.json`（macOS），加入：

```json
{
  "mcpServers": {
    "openmemory": {
      "command": "npx",
      "args": [
        "mcp-remote@latest",
        "http://localhost:8765/mcp/claude-code/sse/your-username",
        "--allow-http"
      ]
    }
  }
}
```

3. 重啟 Claude Desktop
4. 在任何對話中測試：「查 OpenMemory 有沒有關於我的偏好」

### 為什麼需要 `mcp-remote`？

Claude Desktop 的 Custom Connector 要求 HTTPS，而 localhost 是 HTTP。`mcp-remote` 套件將 SSE 轉為 stdio，讓 Claude Desktop 能與本機 OpenMemory 伺服器溝通。
