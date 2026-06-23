#!/bin/sh
# Packmind plugin install tracking — POSIX sh
# Fires on SessionStart; always exits 0 (never delays the session).
# Pure POSIX — no bashisms, no external tools.

SIDECAR_DIR="$(dirname "$0")"
SIDECAR="${SIDECAR_DIR}/packmind-tracking.env"

# Load sidecar config (provides PACKMIND_MARKETPLACE_NAME, PACKMIND_PLUGIN_SLUG,
#   PACKMIND_TRACKING_TOKEN, PACKMIND_API_BASE_URL)
if [ ! -f "$SIDECAR" ]; then exit 0; fi
# shellcheck disable=SC1090
. "$SIDECAR"

PLUGIN_SLUG="product"
# MARKETPLACE_NAME is read from the sidecar as $PACKMIND_MARKETPLACE_NAME
# to prevent shell injection from free-text marketplace names.
MARKETPLACE_NAME="${PACKMIND_MARKETPLACE_NAME}"

# The enabledPlugins key Claude Code writes is "<pluginName>@<marketplace>",
# where both names come from the marketplace descriptor on the client — NOT
# the Packmind package slug / marketplace entity name baked into the sidecar
# (which often differ in case or value). Derive the real key components from
# CLAUDE_PLUGIN_ROOT (.../<marketplace>/<plugin>/<version>) so scope detection
# matches; fall back to the baked values when the path is unavailable.
ENABLED_PLUGIN_NAME="${PLUGIN_SLUG}"
ENABLED_MARKETPLACE_NAME="${MARKETPLACE_NAME}"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  _pr="${CLAUDE_PLUGIN_ROOT%/}"
  _plugin_dir="$(dirname "$_pr")"
  _marketplace_dir="$(dirname "$_plugin_dir")"
  ENABLED_PLUGIN_NAME="$(basename "$_plugin_dir")"
  ENABLED_MARKETPLACE_NAME="$(basename "$_marketplace_dir")"
fi

# ── 1. Scope detection (local → project → user; first match wins) ────────
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCOPE=""

_json_get() {
  # Extract a simple string value from a flat JSON object by key.
  # Usage: _json_get <key> <file>
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$2" 2>/dev/null \
    | sed 's/.*"[^"]*"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/' 2>/dev/null \
    | head -n1
}

_env_get() {
  # Extract a KEY=value from a flat .env file. Usage: _env_get <key> <file>
  # Tolerates leading whitespace and an `export ` prefix; first match wins;
  # strips one layer of surrounding quotes. Parse-only — the file is NEVER
  # sourced, so a hostile repo .env cannot execute code on SessionStart.
  [ -f "$2" ] || return 0
  _v="$(grep -E "^[[:space:]]*(export[[:space:]]+)?$1=" "$2" 2>/dev/null | head -n1)"
  _v="${_v#*=}"
  _v="${_v%\"}"; _v="${_v#\"}"
  _v="${_v%\'}"; _v="${_v#\'}"
  printf '%s' "$_v"
}

_enabled_plugins_has_plugin() {
  # Check if enabledPlugins contains the key "<pluginName>@<marketplace>".
  # Uses positional parameter instead of local (pure POSIX).
  # The key components are derived at runtime from CLAUDE_PLUGIN_ROOT (shell
  # variables, not TS interpolations) so no free-text injection is possible.
  [ -f "$1" ] || return 1
  grep -q "\"${ENABLED_PLUGIN_NAME}@${ENABLED_MARKETPLACE_NAME}\"" "$1" 2>/dev/null
}

if _enabled_plugins_has_plugin "${PROJECT_DIR}/.claude/settings.local.json"; then
  SCOPE="local"
elif _enabled_plugins_has_plugin "${PROJECT_DIR}/.claude/settings.json"; then
  SCOPE="project"
elif _enabled_plugins_has_plugin "${HOME}/.claude/settings.json"; then
  SCOPE="user"
else
  # Plugin not found in any known settings — skip POST (scope is required).
  exit 0
fi

# ── 2. Repo detection (skipped for user scope — not repo-bound) ──────────
REPO_REMOTE_URL=""
if [ "$SCOPE" != "user" ] && command -v git >/dev/null 2>&1; then
  REPO_REMOTE_URL="$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || true)"
fi

# ── 3. Identity resolution ───────────────────────────────────────────────
AUTH_HEADER=""
ANON_ID_HASH=""
ANON_EMAIL_MASKED=""

# Packmind API key resolution order (same precedence as the CLI, plus a
# project .env between the env vars and the global credentials file):
#   PACKMIND_API_KEY env → PACKMIND_API_KEY_V3 env
#   → <project>/.env (PACKMIND_API_KEY, then PACKMIND_API_KEY_V3)
#   → the ~/.packmind credentials file
API_KEY=""
if [ -n "${PACKMIND_API_KEY:-}" ]; then
  API_KEY="${PACKMIND_API_KEY}"
elif [ -n "${PACKMIND_API_KEY_V3:-}" ]; then
  API_KEY="${PACKMIND_API_KEY_V3}"
else
  ENV_FILE="${PROJECT_DIR}/.env"
  API_KEY="$(_env_get PACKMIND_API_KEY "$ENV_FILE")"
  if [ -z "$API_KEY" ]; then
    API_KEY="$(_env_get PACKMIND_API_KEY_V3 "$ENV_FILE")"
  fi
  if [ -z "$API_KEY" ]; then
    CREDS_FILE="${HOME}/.packmind/credentials.json"
    if [ -f "$CREDS_FILE" ]; then
      API_KEY="$(_json_get apiKey "$CREDS_FILE")"
    fi
  fi
fi
if [ -n "$API_KEY" ]; then
  AUTH_HEADER="Authorization: Bearer ${API_KEY}"
fi

# Claude account email → mask + hash (email never leaves the machine)
CLAUDE_JSON="${HOME}/.claude.json"
CLAUDE_EMAIL=""
if [ -f "$CLAUDE_JSON" ]; then
  CLAUDE_EMAIL="$(_json_get emailAddress "$CLAUDE_JSON")"
fi

if [ -n "$CLAUDE_EMAIL" ]; then
  # Mask: first char of each local-part segment, e.g. b**.s***@acme.com
  LOCAL_PART="$(printf '%s' "$CLAUDE_EMAIL" | sed 's/@.*//')"
  DOMAIN_PART="$(printf '%s' "$CLAUDE_EMAIL" | sed 's/[^@]*@//')"
  MASKED_LOCAL=""
  # Iterate segments separated by '.'
  _remaining="$LOCAL_PART"
  while [ -n "$_remaining" ]; do
    _seg="${_remaining%%.*}"
    if [ "${_remaining}" = "${_seg}" ]; then
      _remaining=""
    else
      _remaining="${_remaining#*.}"
    fi
    _first="$(printf '%s' "$_seg" | cut -c1)"
    _stars="$(printf '%s' "$_seg" | cut -c2- | sed 's/./*/g')"
    if [ -n "$MASKED_LOCAL" ]; then
      MASKED_LOCAL="${MASKED_LOCAL}.${_first}${_stars}"
    else
      MASKED_LOCAL="${_first}${_stars}"
    fi
  done
  ANON_EMAIL_MASKED="${MASKED_LOCAL}@${DOMAIN_PART}"

  # SHA-256 hash of the lowercased email
  EMAIL_LOWER="$(printf '%s' "$CLAUDE_EMAIL" | tr '[:upper:]' '[:lower:]')"
  if command -v shasum >/dev/null 2>&1; then
    ANON_ID_HASH="$(printf '%s' "$EMAIL_LOWER" | shasum -a 256 | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    ANON_ID_HASH="$(printf '%s' "$EMAIL_LOWER" | sha256sum | awk '{print $1}')"
  elif command -v openssl >/dev/null 2>&1; then
    ANON_ID_HASH="$(printf '%s' "$EMAIL_LOWER" | openssl dgst -sha256 | awk '{print $NF}')"
  fi
fi

# ── 3b. Installed version ────────────────────────────────────────────────
# Read the installed plugin version from its manifest; fall back to the
# version segment of CLAUDE_PLUGIN_ROOT (.../<plugin>/<version>).
INSTALLED_VERSION=""
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  INSTALLED_VERSION="$(_json_get version "${CLAUDE_PLUGIN_ROOT%/}/.claude-plugin/plugin.json")"
  if [ -z "$INSTALLED_VERSION" ]; then
    INSTALLED_VERSION="$(basename "${CLAUDE_PLUGIN_ROOT%/}")"
  fi
fi

# ── 4. Build JSON payload ─────────────────────────────────────────────────
PAYLOAD="{\"pluginSlug\":\"${PLUGIN_SLUG}\",\"marketplaceName\":\"${MARKETPLACE_NAME}\",\"scope\":\"${SCOPE}\""
if [ -n "$INSTALLED_VERSION" ]; then
  PAYLOAD="${PAYLOAD},\"installedVersion\":\"${INSTALLED_VERSION}\""
fi
if [ -n "$REPO_REMOTE_URL" ]; then
  PAYLOAD="${PAYLOAD},\"repoRemoteUrl\":\"${REPO_REMOTE_URL}\""
fi
if [ -n "$ANON_ID_HASH" ]; then
  PAYLOAD="${PAYLOAD},\"anonymousIdHash\":\"${ANON_ID_HASH}\""
fi
if [ -n "$ANON_EMAIL_MASKED" ]; then
  PAYLOAD="${PAYLOAD},\"anonymousEmailMasked\":\"${ANON_EMAIL_MASKED}\""
fi
PAYLOAD="${PAYLOAD}}"

# ── 5. POST heartbeat (backgrounded, 3s timeout) ─────────────────────────
if command -v curl >/dev/null 2>&1; then
  (
    if [ -n "$AUTH_HEADER" ]; then
      curl --max-time 3 --silent --output /dev/null --show-error \
        -X POST "${PACKMIND_API_BASE_URL}/tracking/plugin-installs" \
        -H "Content-Type: application/json" \
        -H "X-Packmind-Tracking-Token: ${PACKMIND_TRACKING_TOKEN}" \
        -H "${AUTH_HEADER}" \
        -d "$PAYLOAD" 2>/dev/null || true
    else
      curl --max-time 3 --silent --output /dev/null --show-error \
        -X POST "${PACKMIND_API_BASE_URL}/tracking/plugin-installs" \
        -H "Content-Type: application/json" \
        -H "X-Packmind-Tracking-Token: ${PACKMIND_TRACKING_TOKEN}" \
        -d "$PAYLOAD" 2>/dev/null || true
    fi
  ) &
fi

exit 0
