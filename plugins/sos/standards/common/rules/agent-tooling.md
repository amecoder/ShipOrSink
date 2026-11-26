# Agent Tooling Rules

Agent tools must be configured so automation is useful, auditable, and bounded.

## Required Files

- `AGENTS.md`: shared project rules and command map.
- `CLAUDE.md`: Claude Code adapter and project imports.
- `GEMINI.md` or `.gemini/settings.json`: Gemini context adapter.
- `.claude/settings.json`: team-shared Claude permissions and hooks.
- `.claude/hooks/`: formatting, guardrails, and validation hooks.
- `.gitignore`: local-only agent settings and secrets excluded.

## Tool Rules

- Prefer read-only exploration before edits.
- Use allowlists for routine commands and denylists for destructive commands.
- Keep hooks deterministic and fast; they should fail loudly with actionable output.
- Use official docs or repository-local docs for tool behavior that may have changed.
- Track generated artifacts that affect build, tests, docs, or user behavior.

## Safety Rules

- Never grant agents blanket access to secrets or production systems by default.
- Use environment-specific credentials and least privilege.
- Require human approval for destructive infrastructure, data deletion, force pushes, and production deploys.
- Keep personal agent settings out of shared templates.
- Headless runs (`claude -p`, Agent SDK, CI) load the repository's `.mcp.json` servers without the approval prompt: run them with `--strict-mcp-config --mcp-config <reviewed file>` (Claude Code 2.1.246+) or list servers in `disabledMcpjsonServers`.
- Never hand user or CI tokens to an MCP server to forward to other APIs (token passthrough); give each server its own scoped credential.
