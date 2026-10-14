# bropencode

[opencode](https://opencode.ai) v2 in a hardened Docker container, talking to one
OpenAI-compatible endpoint through an allowlist proxy.

## Setup

```sh
cp .env.example .env              # fill in MODEL_BASE_URL, MODEL, MODEL_API_KEY
docker compose build
ln -s "$PWD/oc-here" ~/.local/bin/oc-here
```

## Usage

```sh
cd ~/code/some-project
oc-here                  # TUI against $PWD
oc-here run "fix the failing test"
oc-here --root ~/code    # mount ~/code, start in the subdir you're in
oc-here --shell          # bash in the same sandbox
```

For a model server on this machine, use `http://host.docker.internal:<port>/v1`.

## What's locked down

- **Filesystem:** only the project dir is mounted. Root fs is read-only, `$HOME` is a tmpfs,
  sessions persist in the `opencode-data` volume.
- **Process:** runs as your uid/gid, no capabilities, `no-new-privileges`, pid and memory limits.
- **Network:** the container sits on a network with no route out. A Squid sidecar is the only
  way off it and allows the `MODEL_BASE_URL` host plus `ALLOWED_DOMAINS` (`*` = everything).
- **opencode config** (rendered by `entrypoint.sh`; a project's own `opencode.json` is ignored):
  - **Web search is off.** In v2 it is on by default and sends queries to Exa, Firecrawl,
    Parallel, Tavily or TinyFish. Here it's removed (`websearch: false`), denied by permission
    and by policy, and those hosts aren't on the allowlist.
  - **Web fetch asks** before every URL, and can only reach allowlisted hosts.
  - **Only the configured provider** may be used (`provider.use` policy).
  - **No calls home:** update checks, the models.opencode.ai catalog, session sharing and LSP
    servers are disabled.
- The API key is passed by env and never written to disk.

## Upgrading opencode

Bump `OPENCODE_VERSION` and `OPENCODE_SHA512` in the `Dockerfile` (the comment there shows
how to get the hash), rebuild, and check `docker compose logs proxy` after a session.
