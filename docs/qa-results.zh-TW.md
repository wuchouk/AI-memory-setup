# QA 測試結果

## 測試框架

QA 套件驗證 OpenMemory 部署的 6 個層級，從基礎設施健康到重啟恢復。每個層級基於前一個層級。

**執行完整套件：**
```bash
USER_ID=your-username ./scripts/test-qa.sh all
```

**執行特定層級：**
```bash
USER_ID=your-username ./scripts/test-qa.sh level1
```

## 測試層級

### Level 1: 基礎設施

驗證所有服務正在運行且配置正確。

| 測試 | 檢查項目 | 通過標準 |
|------|---------|---------|
| 1.1 Ollama | 模型載入 | >= 2 個模型（qwen3:8b + nomic-embed-text） |
| 1.2 API | FastAPI 端點 | /docs 回傳 HTTP 200 |
| 1.3 Qdrant | 向量維度 | Collection 使用 768 維 |
| 1.4 UI | Dashboard | :3080 回傳 HTTP 200 |
| 1.5 Docker | 重啟策略 | API 容器設為 `restart: always` |
| 1.6 Ollama service | 自動啟動 | `brew services` 顯示 `started` |
| 1.7 LLM config | Provider | `ollama/qwen3:8b` |

### Level 2: 寫入驗證

測試記憶可從多個客戶端身份寫入。

| 測試 | 檢查項目 |
|------|---------|
| 2.1 | 從 client-a 寫入（模擬 MCP 客戶端） |
| 2.2 | 從 client-b 寫入（模擬 REST 客戶端） |

> **注意**：如果 mem0 判定內容是重複或非事實性的，寫入可能返回 `null`。這是警告，不是失敗。

### Level 3: 跨客戶端讀取

驗證不同客戶端寫入的記憶可從同一個 user_id 存取。

| 測試 | 檢查項目 |
|------|---------|
| 3.1 | 記憶總數 > 0 |
| 3.2 | 所有記憶可從單一查詢讀取 |

### Level 4: MCP 連線

測試 Claude Code 使用的 MCP (SSE) 整合路徑。

| 測試 | 檢查項目 |
|------|---------|
| 4.1 | MCP SSE 端點回傳 HTTP 200 |
| 4.2 | Claude Code 已註冊 openmemory（選擇性） |
| 4.3 | 完整的寫入+讀取循環 |

### Level 5: REST API

測試非 MCP 工具使用的 REST API 路徑。

| 測試 | 檢查項目 |
|------|---------|
| 5.1 | REST 寫入（POST /api/v1/memories/） |
| 5.2 | REST 列表（GET /api/v1/memories/） |
| 5.3 | REST 篩選（POST /api/v1/memories/filter） |

### Level 6: 重啟恢復（手動）

驗證資料在完整重啟循環後持續存在。此測試提供手動執行步驟：

1. 記下目前記憶數量
2. 停止全部：`docker compose down && brew services stop ollama`
3. 重新啟動：`brew services start ollama && docker compose up -d`
4. 重新執行 Level 1 測試
5. 驗證記憶數量一致

## 範例輸出

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
  （手動步驟已列出）

Done.
```

## 環境變數

QA 腳本可完全透過環境變數配置：

```bash
USER_ID=your-username \
API_URL=http://localhost:8765 \
OLLAMA_URL=http://localhost:11434 \
QDRANT_URL=http://localhost:6333 \
UI_URL=http://localhost:3080 \
./scripts/test-qa.sh all
```
