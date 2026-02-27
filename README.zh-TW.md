# AI Memory Setup

**AI 工具的共享記憶層——完全本機執行，零雲端費用。**

[English](README.md)

## 為什麼需要這個？

如果你在工作流程中使用多個 AI 工具（例如 Claude Code 寫程式 + AI 聊天機器人處理其他事），你一定注意到了：**它們之間不會互通。**

每個工具都維護自己孤立的記憶。Claude Code 不知道你的聊天機器人昨天討論了什麼。你的聊天機器人不知道 Claude Code 剛重構了資料庫 schema。你只能一遍又一遍地向每個工具重複相同的上下文、偏好和決策。

**這個專案就是要解決這個問題。**

它部署 [OpenMemory (mem0)](https://github.com/mem0ai/mem0) 作為**統一的記憶層**，讓所有 AI 工具都能讀寫：

```
┌─────────────────┐                    ┌──────────────────────┐
│  Claude Code     │──── MCP (SSE) ───▶│                      │
└─────────────────┘                    │   OpenMemory API     │──▶ Qdrant（向量資料庫）
                                       │   (FastAPI)          │
┌─────────────────┐                    │                      │──▶ Ollama（本機 LLM）
│  AI 聊天機器人    │──── REST API ────▶│                      │
└─────────────────┘                    └──────────────────────┘
```

### 它帶來什麼

- **共享上下文**：偏好只需設定一次，所有工具都記得
- **語意搜尋**：用語意而非關鍵字找到相關記憶
- **自動事實擷取**：mem0 從對話中提煉原子事實
- **完全隱私**：所有東西都在本機執行——Ollama LLM、Qdrant 向量、資料不離開你的電腦
- **零 API 費用**：不需要 OpenAI key（使用本機 Ollama 模型）
- **重啟自恢復**：Docker + brew services 自動啟動

### 解決了什麼問題

| 沒有共享記憶 | 有共享記憶 |
|------------|----------|
| 每個工具都要重複解釋偏好 | 設定一次，到處可用 |
| 工具 A 不知道工具 B 改了什麼 | 兩者從同一個來源讀取 |
| 除錯經驗在 session 間遺失 | 持久化且可搜尋 |
| 上下文散落在各工具中 | 統一的事實資料庫 |

## 快速開始

### 前置條件

- macOS Apple Silicon（M1/M2/M3/M4）
- Docker Desktop
- Homebrew
- 16GB+ RAM（建議 24GB）

### 1. 安裝 Ollama + 模型

```bash
./scripts/setup-ollama.sh
```

### 2. 部署 Docker 堆疊

```bash
cd ~
git clone https://github.com/mem0ai/mem0.git
cd mem0/openmemory

# 建立 .env
cat > api/.env << 'EOF'
USER=your-username
OPENAI_API_KEY=not-needed
OLLAMA_HOST=http://host.docker.internal:11434
EOF

# 自訂 docker-compose.yml（參考 config/docker-compose.yml）
# Build 和啟動
make build
NEXT_PUBLIC_USER_ID=your-username \
NEXT_PUBLIC_API_URL=http://localhost:8765 \
docker compose up -d
```

### 3. 設定本機 Ollama

```bash
./scripts/configure-mem0.sh
```

### 4. 連接你的 AI 工具

**Claude Code (MCP)**:
```bash
claude mcp add -s user openmemory --transport sse \
  http://localhost:8765/mcp/claude-code/sse/your-username
```

**其他工具 (REST)**:
```bash
curl -s -X POST http://localhost:8765/api/v1/memories/ \
  -H 'Content-Type: application/json' \
  -d '{"text": "要記住的內容", "user_id": "your-username", "agent_id": "my-tool"}'
```

### 5. 驗證

```bash
USER_ID=your-username ./scripts/test-qa.sh all
```

## 文件

| 文件 | 說明 |
|------|------|
| [架構說明](docs/architecture.zh-TW.md) | 系統設計、元件角色、資料流 |
| [部署指南](docs/deployment-guide.zh-TW.md) | 完整的逐步部署流程 |
| [疑難排解](docs/troubleshooting.zh-TW.md) | 5 大問題 + FAQ |
| [Claude Code 整合](docs/integration-claude-code.zh-TW.md) | Claude Code 的 MCP 設定 |
| [REST API 整合](docs/integration-openclaw.zh-TW.md) | 其他工具的 REST 存取 |
| [QA 測試結果](docs/qa-results.zh-TW.md) | 6 層級測試套件 |
| [環境與工具](docs/environment.zh-TW.md) | 工具版本和配置 |

所有文件提供[英文](docs/)和[繁體中文](docs/)版本。

## 設定範本

| 檔案 | 用途 |
|------|------|
| [docker-compose.yml](config/docker-compose.yml) | 有註解的 Docker 配置 |
| [env.example](config/env.example) | 環境變數範本 |
| [claude-mcp-config.example.json](config/claude-mcp-config.example.json) | MCP server 設定 |
| [claude-md-snippet.md](config/claude-md-snippet.md) | Claude Code 的 CLAUDE.md 指引 |
| [openclaw-agents-snippet.md](config/openclaw-agents-snippet.md) | REST 工具的配置片段 |

## 技術堆疊

| 元件 | 工具 | 版本 |
|------|------|------|
| 記憶引擎 | [mem0 / OpenMemory](https://github.com/mem0ai/mem0) | v1.0.4+ |
| 向量資料庫 | [Qdrant](https://qdrant.tech/) | v1.17.0 |
| LLM（事實擷取） | [Ollama](https://ollama.ai/) + qwen3:8b | 0.17.0 |
| 嵌入模型 | nomic-embed-text | 768 維度 |
| 容器執行環境 | Docker Desktop | 4.62.0 |
| API 框架 | FastAPI | >=0.68.0 |

完整列表見 [docs/environment.zh-TW.md](docs/environment.zh-TW.md)。

## 授權

[MIT](LICENSE)
