# 架構說明

## 問題：AI 失憶症

現代 AI 程式助手（Claude Code、Cursor 等）和 AI 聊天機器人各自維護獨立的記憶系統。當你的工作流程使用多個 AI 工具時，每個工具每次 session 都從零開始，而且彼此不知道對方學到了什麼。

這會造成實際問題：

- **重複交代背景**：每個工具都要分別解釋同樣的偏好、決策和專案背景
- **知識不一致**：工具 A 不知道工具 B 昨天改了關鍵配置
- **機構知識流失**：重要的除錯經驗、架構決策和使用者偏好散落在多個孤立的記憶系統中
- **Session 失憶**：即使在同一個工具內，長時間的上下文在 session 之間也會遺失

### 為什麼現有方案不夠

| 方案 | 限制 |
|------|------|
| 工具內建記憶（如 Claude 的 auto-memory） | 孤島——其他工具無法存取 |
| 手動文件（README、wiki） | 需要紀律，容易過時 |
| 複製貼上上下文 | 繁瑣、容易出錯、不可擴展 |
| 雲端記憶服務 | 隱私疑慮、API 費用、供應商鎖定 |

## 解法：本機共享記憶層

**OpenMemory** 作為統一的事實資料庫，所有 AI 工具都能讀寫：

- 穩定事實（偏好、決策、配置）的單一真相來源
- 語意向量搜尋——用語意而非關鍵字找到相關記憶
- 自動事實擷取——mem0 從對話中提煉原子事實
- 完全本機——Ollama LLM 在你的機器上執行，零雲端 API 費用，完全隱私

## 架構圖

```
┌─────────────────┐     MCP (SSE)      ┌──────────────────────┐
│  Claude Code     │───────────────────▶│                      │
│  (MCP client)    │                    │   OpenMemory API     │──▶ Qdrant（向量）
└─────────────────┘                    │   (FastAPI :8765)    │──▶ SQLite（metadata）
                                       │                      │
┌─────────────────┐     REST API       │                      │──▶ Ollama (LLM + Embed)
│  AI 助手         │───────────────────▶│                      │     (localhost:11434)
│  (REST client)   │  curl localhost    └──────────────────────┘
└─────────────────┘
                                       ┌──────────────────────┐
                                       │   Dashboard UI       │
                                       │   (Next.js :3080)    │
                                       └──────────────────────┘
```

## 元件角色

### OpenMemory API (FastAPI)

中央樞紐。接收記憶讀寫請求，委派 Ollama 進行事實擷取和嵌入，將結果儲存到 Qdrant。

- **Port**: 8765
- **協定**: MCP (SSE) 給 Claude Code，REST 給其他工具
- **主要端點**: `/api/v1/memories/`、`/api/v1/config/`、`/mcp/claude-code/sse/{user_id}`

### Ollama（本機 LLM）

在你的機器上執行兩個模型：

| 模型 | 角色 | 大小 | 選擇原因 |
|------|------|------|----------|
| qwen3:8b | 事實擷取 | ~5.2GB | 中英文夾雜理解能力強 |
| nomic-embed-text | 向量嵌入 | ~274MB | 768 維度、開源、品質接近 OpenAI |

**為什麼本機？** 零 API 費用、資料不離開你的電腦、離線也能用。

### Qdrant（向量資料庫）

儲存記憶的嵌入向量，用於語意搜尋。當你搜尋「我的程式風格偏好」，即使記憶中沒有這些確切的字，也能找到相關內容。

- **Port**: 6333
- **維度**: 768（必須與 nomic-embed-text 一致）
- **儲存**: Docker volume (`mem0_storage`)

### Dashboard UI (Next.js)

瀏覽、搜尋和管理記憶的視覺介面。

- **Port**: 3080（從容器的 3000 映射，避免衝突）

## 資料流

### 寫入記憶

```
使用者/AI 工具 → POST /api/v1/memories/
  → mem0 引擎 → Ollama（從文字擷取原子事實）
  → Ollama（生成嵌入向量）
  → Qdrant（儲存向量 + metadata）
  → 回傳擷取的事實或 null（若無新事實）
```

### 讀取/搜尋記憶

```
使用者/AI 工具 → GET /api/v1/memories/（列表）或 MCP search_memory（語意搜尋）
  → Qdrant（向量相似度搜尋）
  → 回傳排序後的結果
```

## 設計決策

### 為什麼 MCP + REST（不是只有 MCP）？

不是所有 AI 工具都支援 Model Context Protocol。Claude Code 有原生 MCP 支援，但其他工具（自訂機器人、腳本）需要 REST。OpenMemory 同時提供兩種協定：

- **MCP (SSE)**：給 MCP 相容的客戶端如 Claude Code——提供 `search_memory`、`add_memories` 等原生工具
- **REST**：給其他一切——簡單的 curl 存取

### 為什麼所有容器都設 `restart: always`？

系統應該能在重開機後自動恢復，不需手動介入。搭配 Ollama 的 `brew services` 自動啟動，整個堆疊在斷電重啟後自動上線。

### 為什麼 UI 用 port 3080？

Port 3000、3001、3002 常被開發伺服器佔用（Next.js、Create React App 等）。用 3080 避免衝突。

### 為什麼在 docker-compose.yml 中寫死 USER？

Docker 的 `environment: - USER` 會繼承主機的 `$USER`，可能跟你的 OpenMemory 使用者名稱不同。寫死可以防止隱蔽的「user not found」錯誤。

## RAM 預算

| 元件 | RAM 使用量 |
|------|-----------|
| macOS 系統 | ~4GB |
| Ollama (qwen3:8b + nomic-embed-text) | ~7GB（閒置時卸載） |
| Docker (FastAPI + Qdrant) | ~2-3GB |
| 其他應用 | ~5-7GB |
| **總計** | **~18-21GB / 24GB** |

**最低建議**：16GB RAM（使用較小的 LLM 如 qwen3:4b）
**舒適配置**：24GB+ RAM

## 未來考量

- **多機存取**：使用 Tailscale 或類似 VPN 從其他裝置連入
- **備份策略**：定期匯出 Qdrant 快照
- **模型升級**：新模型推出時替換 qwen3:8b
