# 疑難排解

部署過程中遇到的常見問題——以及如何解決。

## 1. Qdrant 維度不匹配（最常見）

**症狀**: `shapes (0,1536) and (768,) not aligned`

**原因**: API 啟動時用 OpenAI 預設 config 初始化，Qdrant collection 被建成 1536 維。但 nomic-embed-text 是 768 維。

**解法**——三步缺一不可：

```bash
# 1. 透過 Config API 設定 embedding_model_dims: 768
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

# 2. 刪除已建立的 Qdrant collection
curl -X DELETE http://localhost:6333/collections/openmemory
curl -X DELETE http://localhost:6333/collections/mem0migrations

# 3. 重啟 API container
docker compose restart openmemory-mcp
sleep 8
```

**驗證**:
```bash
curl -s http://localhost:6333/collections/openmemory | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['result']['config']['params']['vectors']['size'])"
# 應顯示: 768
```

## 2. Docker USER 環境變數

**症狀**: 寫入記憶時出現 `User not found`

**原因**: docker-compose.yml 的 `environment: - USER` 從主機繼承 `$USER`，可能跟你的 OpenMemory 使用者名稱不同。

**解法**: 在 docker-compose.yml 中寫死使用者名稱：
```yaml
environment:
  - USER=your-username    # 寫死——不要用 '- USER'
```

## 3. mem0 返回 null

**症狀**: POST 到 `/api/v1/memories/` 返回 `null`，HTTP 200

**原因**: mem0 判定輸入文本沒有新的事實可提取（可能和已有記憶重複，或內容不是事實性陳述）。

**這是正常行為。** mem0 只儲存它認為是「新的、有事實價值的」資訊。試試寫入更具體的內容：

```bash
# 太模糊（可能返回 null）：
curl ... -d '{"text": "test", ...}'

# 較好（含可提取的事實）：
curl ... -d '{"text": "專案使用 PostgreSQL 16 搭配 pgvector 做向量嵌入。", ...}'
```

## 4. Categorization 401 Error

**症狀**: API 日誌中出現 `Failed to get categories: Error code: 401`

**原因**: 記憶分類功能嘗試呼叫 OpenAI API。如果你使用 Ollama 且 API key 設為 `not-needed`，分類會因 401 失敗。這不影響核心記憶讀寫。

**解法**:
- **OpenAI 使用者**：使用真正的 OpenAI API key 時此問題已解決——分類功能正常運作。
- **Ollama 使用者**：可安全忽略。分類是非關鍵功能，核心記憶操作不受影響。你也可以註解掉 `api/app/models.py` 中的 event listener 來完全停用。

## 5. 寫入速度慢（10-30 秒）

**症狀**: 每次記憶寫入需要 10-30 秒

**原因**: 每次寫入都要跑 Ollama 推理（事實提取 + embedding）。首次寫入最慢，因為 Ollama 需要將模型載入 RAM。

**這是正常現象。** Ollama 閒置時自動卸載模型，首次推理需要載入時間。

**緩解方式**:
- Session 中的首次寫入必然較慢（~20-30 秒載入模型）
- 後續寫入較快（~5-15 秒）
- 若太慢，考慮使用較小的模型如 `qwen3:4b`（省 ~3GB RAM，推理更快）
- **最快方案**：改用 OpenAI 作為 LLM provider（每次寫入約 5-7 秒，Ollama 則約 25 秒）。設定方式請參考[部署指南](deployment-guide.zh-TW.md)

## 6. OpenAI 靜默返回 Null（max_tokens 太低）

**症狀**: POST 到 `/api/v1/memories/` 返回 `null`，但 Docker 日誌顯示：
```
Invalid JSON response: Unterminated string
```

**原因**: `max_tokens` 設定太低（例如 500）。mem0 的事實擷取 prompt 會包含所有相關的現有記憶，用於去重和比對。隨著記憶庫成長，越來越多相關記憶被加入 prompt，LLM 的回應 JSON 可能超過 token 上限而被截斷——產生無效的 JSON，mem0 會靜默丟棄。

**解法**: 將 `max_tokens` 設為至少 2000（建議 4096）。OpenAI 按實際輸出 token 計費，不是按設定的上限，所以提高上限不會增加費用。

```bash
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/llm \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "openai",
    "config": {
      "model": "gpt-4.1-nano",
      "temperature": 0,
      "max_tokens": 4096
    }
  }'
```

更新後重啟 API container：
```bash
docker compose restart openmemory-mcp
```

## 7. 事實擷取過度拆分（Ollama / 小型模型）

**症狀**：一次 `add_memories` 呼叫產生 5-8 筆碎片記憶，而不是 1-2 筆完整的。無用碎片範例：
- `"Source: OpenMemory project 2026-02-27"` — metadata 被當成獨立「事實」提取
- `"只檢查本身進程健康"` — 孤立片段，缺乏上下文
- `"Works in Chat, Cowork, and Code modes"` — 不完整；什麼東西 works？

**原因**：mem0 的事實擷取流程會要求 LLM 將輸入拆解為「原子事實」。較小的模型如 qwen3:8b 會過度拆分——把 metadata 當事實提取、丟失上下文、產生脫離原文就無法理解的碎片。較大的模型（如 gpt-4.1-nano）也有此問題，但程度輕微得多。

**影響**：隨著時間推移，記憶庫會充滿缺乏上下文的碎片，污染搜尋結果、浪費儲存空間。我們使用 qwen3:8b 的實測中，**67 筆記憶有 29 筆（約 43%）是碎片**，需要手動清理。

**解法**：設定 `custom_fact_extraction_prompt` 來約束擷取行為。適用於任何 LLM 供應商：

```bash
curl -s -X PUT http://localhost:8765/api/v1/config/openmemory \
  -H 'Content-Type: application/json' \
  -d '{
    "custom_instructions": "Extract facts conservatively and return as json. Rules:\n1. Maximum 3 facts per input. Prefer fewer, more complete facts over many fragments.\n2. Each fact MUST be self-contained and understandable without the original text. Include WHO, WHAT, and WHY/CONTEXT.\n3. Do NOT extract metadata (dates, sources) as separate facts — embed them within the relevant fact.\n4. Do NOT extract vague or generic statements. Only extract specific, actionable information.\n5. Preserve technical details (commands, paths, config values) within their context.\n6. If the input is already a single coherent fact, return it as-is without splitting."
  }'
```

> **重要**：custom instructions **必須**包含 "json" 這個詞——OpenAI 的 `response_format: json_object` 要求 messages 中出現它。少了 "json"，`add_memories` 會回傳 HTTP 400。

**替代方案**：每次 `add_memories` 只寫入一個事實，不要把多個事實合併成一段文字。這樣 LLM 就沒東西可以過度拆分。

## 常見問答

### Q: 可以用其他 LLM 代替 qwen3:8b 嗎？

可以。任何 Ollama 模型都行。更新配置：
```bash
curl -s -X PUT http://localhost:8765/api/v1/config/mem0/llm \
  -H 'Content-Type: application/json' \
  -d '{"provider": "ollama", "config": {"model": "你的模型名稱", ...}}'
```

推薦替代品：
- `qwen3:4b` — 更小、更快、更省 RAM
- `llama3.1:8b` — 純英文使用場景很強
- `gemma2:9b` — Google 的模型，多語言支援不錯

### Q: 可以用其他嵌入模型嗎？

可以，但必須同時更新向量庫配置的 `embedding_model_dims` 以匹配模型的輸出維度，然後刪除並重建 Qdrant collection。參見上方[問題 #1](#1-qdrant-維度不匹配最常見)。

### Q: 如何備份記憶？

匯出 Qdrant 快照：
```bash
curl -X POST http://localhost:6333/collections/openmemory/snapshots
```

或直接備份 Docker volume：
```bash
docker run --rm -v mem0_storage:/data -v $(pwd):/backup \
  alpine tar czf /backup/qdrant-backup.tar.gz /data
```

### Q: 如何清空全部重來？

```bash
# 停止所有服務
cd ~/mem0/openmemory && docker compose down

# 刪除 Qdrant 資料
docker volume rm openmemory_mem0_storage

# 重新啟動
docker compose up -d

# 重新設定（必要！）
./scripts/configure-mem0.sh
```

### Q: 可以用 OpenAI 代替 Ollama 嗎？

可以——這其實是**建議方案**。OpenAI 寫入更快（約 5-7 秒 vs 約 25 秒）、省去本機 LLM 的 RAM 佔用，而且啟用了分類功能。一般個人使用的估計費用約 $0.17/月。

設定方式請參考[部署指南](deployment-guide.zh-TW.md)，包含 LLM 和嵌入模型 provider 的完整設定說明。

### Q: MCP 連線一開始正常但後來斷線？

MCP 只在 Claude Code session 啟動時連線。如果 Docker 在 Claude Code 運行中重啟，連線會斷開。解法：重啟你的 Claude Code session。
