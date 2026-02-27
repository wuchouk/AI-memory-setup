# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-02-27

### Added
- OpenAI API as recommended LLM provider (gpt-4.1-nano + text-embedding-3-small)
- Provider comparison table in deployment guide
- New troubleshooting entry for max_tokens silent failure issue
- Migration guide for switching from Ollama to OpenAI

### Changed
- Deployment guide now presents OpenAI as primary option, Ollama as alternative
- Architecture docs updated to reflect dual-provider support
- Config examples updated with OpenAI option
- Troubleshooting FAQ updated with OpenAI recommendation

### Fixed
- Documented max_tokens silent failure issue (must be ≥2000 for OpenAI, 4096 recommended)
- Auto-categorization now works with OpenAI (was disabled with Ollama due to hardcoded OpenAI dependency)

## [1.0.0] - 2026-02-26

### Added

- Complete bilingual documentation (English + Traditional Chinese)
- Architecture guide with design decisions and data flow diagrams
- Step-by-step deployment guide for macOS Apple Silicon
- Troubleshooting guide covering top 5 deployment issues
- Claude Code integration guide (MCP/SSE)
- REST API integration guide for non-MCP tools
- 6-level QA test suite (`scripts/test-qa.sh`)
- Ollama setup helper script (`scripts/setup-ollama.sh`)
- Post-deployment configuration script (`scripts/configure-mem0.sh`)
- Annotated Docker Compose configuration
- Environment variable template (`config/env.example`)
- MCP configuration example
- Ready-to-use CLAUDE.md and AGENTS.md snippets
- Environment and tooling version documentation
