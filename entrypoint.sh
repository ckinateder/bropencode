#!/bin/sh
# Renders opencode's config from env, then starts opencode.
# The API key is NOT written to disk: the provider reads it from $MODEL_API_KEY.
set -eu

for var in MODEL_BASE_URL MODEL; do
    eval "value=\${$var:-}"
    [ -n "$value" ] || { echo "error: $var is required" >&2; exit 1; }
done

# Values are embedded in JSON below; refuse characters that would break it.
for value in "$MODEL_BASE_URL" "$MODEL"; do
    case "$value" in
        *\"* | *\\*) echo "error: MODEL_BASE_URL/MODEL must not contain \" or \\" >&2; exit 1 ;;
    esac
done

# Blank key (e.g. local models): don't point the provider at an empty variable.
if [ -n "${MODEL_API_KEY:-}" ]; then
    env_line='"env": ["MODEL_API_KEY"],'
else
    env_line=
fi

# websearch is off three ways: no tool (websearch: false), a deny permission, and a deny policy.
# webfetch asks before every URL; the proxy still decides what is reachable.
# Policies (enforced, last match wins) allow only the provider defined here.
config_dir="$HOME/.config/opencode"
mkdir -p "$config_dir"
cat > "$config_dir/opencode.json" <<EOF
{
  "providers": {
    "custom": {
      "name": "Custom",
      $env_line
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": { "baseURL": "$MODEL_BASE_URL" },
      "models": { "$MODEL": {} }
    }
  },
  "model": { "providerID": "custom", "model": "$MODEL" },
  "update": "disable",
  "share": "disabled",
  "lsp": false,
  "websearch": false,
  "permissions": [
    { "action": "websearch", "resource": "*", "effect": "deny" },
    { "action": "webfetch", "resource": "*", "effect": "ask" }
  ],
  "policies": [
    { "action": "provider.use", "resource": "*", "effect": "deny" },
    { "action": "provider.use", "resource": "custom", "effect": "allow" },
    { "action": "tool.use", "resource": "websearch:*", "effect": "deny" }
  ]
}
EOF

exec opencode "$@"
