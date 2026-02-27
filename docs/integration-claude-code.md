# Integration: Claude Code (MCP)

Claude Code supports the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/), which provides native tool-level integration with OpenMemory.

## How It Works

Claude Code connects to OpenMemory via Server-Sent Events (SSE). Once registered, the AI assistant can use `search_memory` and `add_memories` as built-in tools — no curl commands needed.

```
Claude Code  ──SSE──▶  OpenMemory API (:8765)  ──▶  Qdrant + Ollama
```

## Setup

### 1. Register the MCP Server

```bash
claude mcp add -s user openmemory --transport sse \
  http://localhost:8765/mcp/claude-code/sse/your-username
```

- `-s user`: User-level scope (available across all projects)
- `--transport sse`: Server-Sent Events protocol
- Replace `your-username` with your OpenMemory user ID

### 2. Verify Connection

```bash
claude mcp list
```

Expected output:
```
openmemory: http://localhost:8765/mcp/claude-code/sse/your-username ✓ Connected
```

### 3. Add Instructions to CLAUDE.md

Copy the contents of [config/claude-md-snippet.md](../config/claude-md-snippet.md) into your `~/.claude/CLAUDE.md` file. This tells Claude Code:

- **When** to read/write memories (milestone-driven triggers)
- **What** to store (stable facts, not session details)
- **What** to skip (secrets, temporary info, minor fixes)

## Available MCP Tools

Once connected, Claude Code can use these tools:

| Tool | Description |
|------|-------------|
| `search_memory` | Semantic search across all memories |
| `add_memories` | Write new facts to the memory store |
| `list_memories` | List memories with optional filters |
| `delete_memories` | Remove specific memories |

## Usage Examples

In a Claude Code session, the AI will automatically:

```
# When starting a new task:
"Let me check OpenMemory for relevant context..."
→ search_memory("project architecture preferences")

# After making a key decision:
"I'll save this to OpenMemory for cross-tool access..."
→ add_memories("Project switched from REST to GraphQL for the public API")
```

## Troubleshooting

### Connection fails at startup

1. Verify Docker is running: `docker ps | grep openmemory`
2. Test the API directly: `curl -s http://localhost:8765/docs`
3. Test the SSE endpoint: `curl -s http://localhost:8765/mcp/claude-code/sse/your-username`
4. Restart Claude Code (MCP only connects at session start)

### "openmemory" not shown in tool list

- Check registration: `claude mcp list`
- Re-register if needed: `claude mcp remove openmemory && claude mcp add ...`
- Restart your Claude Code session

### Connection works but tools are slow

This is expected — each memory write requires Ollama inference (10-30s). See [troubleshooting](troubleshooting.md#5-slow-write-speed-10-30-seconds).

## Configuration Reference

MCP config file location: `~/.claude/mcp_servers.json`

Example entry:
```json
{
  "openmemory": {
    "type": "sse",
    "url": "http://localhost:8765/mcp/claude-code/sse/your-username"
  }
}
```
