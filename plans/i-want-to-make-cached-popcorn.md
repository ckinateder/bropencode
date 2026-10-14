# bropencode: hardened opencode (v2) container

## Context
Run opencode v2 in a locked-down container that talks to one OpenAI-compatible endpoint and nothing else unless a host is explicitly allowlisted. The goal is that opencode never sends requests to sites Calvdawg didn't approve. Keep it simple for now.

**Rule:** no file in this repo (code, comments, README, plans) refers to any other project by name. Every file stands on its own.

## Research findings (opencode v2.0.29, commit 3a69bae)
- **Package:** `@opencode/cli-linux-x64@2.0.29`, a self-contained glibc binary (211 MB). Tarball sha512 hex `a5d1bf4f…076ca6a4`, verified locally.
- **websearch is ON by default in v2**, for every provider. On first use a form asks you to allow it, then a provider is picked at random (Exa `mcp.exa.ai`, Firecrawl `mcp.firecrawl.dev`, Parallel `search.parallel.ai`, Tavily `api.tavily.com`, TinyFish `agent.tinyfish.ai`). The config key `websearch: false` removes the tool from the model's context.
  → We set `websearch: false`, a `permissions` rule (`websearch` deny), and a `policies` rule (`tool.use` websearch deny). The proxy blocks all five hosts as well.
- **webfetch:** GET on any URL the model picks. → `permissions` rule `webfetch * ask`. The proxy allowlist is the hard boundary.
- **Other call-home hosts in the binary:** `opencode.ai` (update API, theme, OAuth) and `models.opencode.ai`. No third-party telemetry SDKs.
  → `OPENCODE_DISABLE_AUTOUPDATE=1`, `OPENCODE_DISABLE_MODELS_FETCH=1`, `update: "disable"`, `share: "disabled"`, `lsp: false`.
- **Provider:** the bundled `@opencode/ai/providers/openai-compatible` package, so there's no runtime npm install. API key comes in via `env: ["MODEL_API_KEY"]`.
- **Project config:** `OPENCODE_DISABLE_PROJECT_CONFIG=1`, so a repo's `opencode.json` can't loosen any of this.

## Decisions (confirmed)
websearch disabled · webfetch = ask + proxy allowlist · runtime base `node:24-trixie-slim` · include `oc-here` launcher · opencode v2.

## Files (~350 lines total)
| File | ~Lines | Notes |
|---|---|---|
| `Dockerfile` | 45 | Build stage fetches the npm tarball and checks its sha512 (pinned ARGs). Runtime: `node:24-trixie-slim` + `ca-certificates git ripgrep fd-find`, uid 10001, `HOME=/home/opencode`, the env flags above. |
| `entrypoint.sh` | 50 | Requires `MODEL_BASE_URL` and `MODEL`, rejects `"`/`\`. Renders `~/.config/opencode/opencode.json` (v2 schema) on the tmpfs; the API key never touches disk. Then `exec opencode "$@"`. |
| `compose.yaml` | 65 | `internal` network (no route out) + proxy on `egress`, read-only rootfs, tmpfs, `cap_drop ALL`, no-new-privileges, limits. Volume `opencode-data` at `~/.local/share/opencode`. |
| `proxy/Dockerfile`, `proxy/entrypoint.sh` | 80 | Squid allowlist: model host + `ALLOWED_DOMAINS` (`*` = open). |
| `oc-here` | 65 | Launcher: mounts `$PWD`/`--root`, runs as host uid, `--shell`, `--help`. |
| `.env.example` | 1 edit | Fix the stale variable name in a comment. |
| `.gitignore`, `.dockerignore`, `README.md` | 40 | |

## Verification
1. `docker compose build`, then `./oc-here --help`.
2. In `--shell`, a node fetch to example.com is blocked, the model host works, and with no proxy set nothing gets out.
3. `./oc-here run "say hi"` works, and the config loads without schema warnings.
4. Proxy logs show only the model host: no `opencode.ai`, `models.opencode.ai` or search hosts.
5. `/workspace` files are owned by the host user. `grep -ri` for other project names comes back empty.
