# 環境與工具

本次部署使用的工具、版本和配置完整列表。

## 硬體

| 元件 | 規格 |
|------|------|
| 晶片 | Apple M4 |
| 記憶體 | 24GB 統一記憶體 |
| 作業系統 | macOS 15.x (Sequoia) |

## 軟體堆疊

### 核心服務

| 工具 | 版本 | 用途 |
|------|------|------|
| Docker Desktop | 4.62.0 | 容器執行環境 |
| Docker Compose | v5.0.2 | 服務編排 |
| Ollama | 0.17.0 | 本機 LLM 推理 |
| Qdrant | v1.17.0 | 向量資料庫 |
| mem0 (OpenMemory) | v1.0.4+ (commit 93c72030) | 記憶引擎 |

### AI 模型

| 模型 | 大小 | 用途 |
|------|------|------|
| qwen3:8b | ~5.2GB | 中英文事實擷取 |
| nomic-embed-text | ~274MB | 向量嵌入（768 維度） |

### 執行環境與框架

| 工具 | 版本 | 用途 |
|------|------|------|
| Python | 3.9.6+ | API 執行環境 |
| Node.js | v25.x | Dashboard UI 執行環境 |
| FastAPI | >=0.68.0 | API 框架 |
| mem0ai (Python SDK) | >=0.1.92 | 核心記憶庫 |
| MCP SDK | >=1.3.0 | Model Context Protocol |

### 開發工具

| 工具 | 版本 | 用途 |
|------|------|------|
| Homebrew | 5.x | macOS 套件管理 |
| gh CLI | 2.x | GitHub 操作 |
| Claude Code | 2.x | AI 開發助手（MCP 客戶端） |

### AI 後端

| 元件 | 詳情 |
|------|------|
| LLM 提供者 | Claude（透過 Claude Max 訂閱） |
| 模型 | Opus 4 |

## 來源倉庫

| 倉庫 | 用途 |
|------|------|
| [mem0ai/mem0](https://github.com/mem0ai/mem0) | OpenMemory 核心（clone 後自訂） |
| [qdrant/qdrant](https://hub.docker.com/r/qdrant/qdrant) | 向量資料庫 Docker 映像 |

## Port 分配

| Port | 服務 |
|------|------|
| 8765 | OpenMemory API (FastAPI) |
| 6333 | Qdrant 向量資料庫 |
| 3080 | OpenMemory Dashboard UI |
| 11434 | Ollama（LLM 推理） |

## 關鍵配置值

| 設定 | 值 | 原因 |
|------|---|------|
| 向量維度 | 768 | 匹配 nomic-embed-text 輸出 |
| LLM temperature | 0.1 | 低隨機性，適合事實擷取 |
| LLM max_tokens | 2000 | 足夠處理記憶 |
| Docker restart policy | `always` | 重啟自恢復 |
| UI port | 3080 | 避免與開發伺服器衝突 |
| OLLAMA_HOST | `http://host.docker.internal:11434` | Docker 連主機通訊 |
