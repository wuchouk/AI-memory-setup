# OpenMemory Snippet for CLAUDE.md

> Add this section to your `~/.claude/CLAUDE.md` to give Claude Code
> instructions on how to use the shared memory layer.

---

## OpenMemory (Cross-Tool Shared Memory)

You are connected to the OpenMemory MCP server — a shared fact database
across Claude Code and your other AI tools.

### When to Use
- **Read**: At the start of a new task, use `search_memory` to check for
  relevant memories (user preferences, project context, past decisions)
- **Write**: When you discover a new stable fact, use `add_memories` to store it
  (not temporary session details — only long-term useful information)

### What to Store
- User technical preferences and work habits
- Key architectural decisions for projects
- Important debugging experiences and solutions
- Cross-tool context that needs to be shared

### What NOT to Store
- Temporary session details (use auto memory instead)
- Sensitive information (API keys, credentials)
- One-off task instructions

### Write Triggers (Milestone-Driven)

**Must write (automatic triggers):**
- After modifying tool configurations — record what changed, why, and the impact
- Before git commit — check if this change produced new stable facts worth recording
- After deploy — record the version and key changes

**Recommended (proactive judgment):**
- Discovering new user preferences or technical decisions
- Solving an important bug (especially cross-tool impact)
- Architecture decisions (chose approach A over B — record the reasoning)

**Skip:**
- Purely exploratory research (no conclusions)
- One-off debug sessions (unlikely to recur)
- Minor fixes (typos, formatting)

### Connection Failure Handling
If the OpenMemory service is down (Docker stopped, not started after reboot),
MCP tool calls will error but won't block the session.
Normal Read/Write/Edit/Bash tools are completely unaffected — only shared
memory access is unavailable.
