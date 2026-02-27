# OpenMemory Snippet for AGENTS.md

> Add this section to your AI assistant's configuration file (e.g., AGENTS.md)
> to enable REST API access to the shared memory layer.

---

## OpenMemory (Cross-Tool Shared Memory)

OpenMemory is a shared fact database across your AI tools, running locally via Docker.

### API Endpoints (REST, not MCP)
- **List memories**: `curl -s "http://localhost:8765/api/v1/memories/?user_id=your-username"`
- **Add memory**: `curl -s -X POST http://localhost:8765/api/v1/memories/ -H 'Content-Type: application/json' -d '{"text": "content to remember", "user_id": "your-username", "agent_id": "your-agent-name"}'`
- **Dashboard**: http://localhost:3080

### Write Rules
- **Stable facts** (preferences, background, long-term decisions) → write to OpenMemory (cross-tool accessible)
- **Work logs and temporary context** → write to your own memory system
- **Uncertain information** → keep in daily notes, promote later if confirmed

### Write Triggers
- After modifying configurations → write immediately
- Discovering new stable facts (user preferences, technical decisions, architecture choices)
- Solving important bugs (especially cross-tool impact)

### Skip
- Purely exploratory research, one-off debugging, minor fixes

### Connection Failure
If curl to localhost:8765 fails, the service may not be running. This does not
affect normal operations.
