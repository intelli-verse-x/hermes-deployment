#!/usr/bin/env bash
#
# install-local.sh — install Hermes Agent locally with the intelli-verse-x
# config pre-wired.
#
# Run on macOS / Linux / WSL2:
#
#     curl -fsSL https://raw.githubusercontent.com/intelli-verse-x/hermes-deployment/main/scripts/install-local.sh | bash
#
# Or from a checkout:
#
#     ./scripts/install-local.sh
#
# What it does:
#   1. Installs hermes-agent via the official one-liner if not already
#      installed.
#   2. Drops our config.yaml + AGENTS.md into ~/.hermes/ (won't overwrite
#      existing files — diffs first).
#   3. Drops our bundled skills into ~/.hermes/skills/ via symlink, so
#      `git pull` in this repo updates them.
#   4. Prints what env vars you still need to fill in.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }

bold "1. Checking hermes-agent install..."
if ! command -v hermes >/dev/null 2>&1; then
  bold "   not installed; running the official one-liner"
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
fi
ok "hermes binary: $(command -v hermes)"

mkdir -p "$HERMES_HOME"
mkdir -p "$HERMES_HOME/skills"

bold "2. Seeding config..."
for f in config.yaml AGENTS.md; do
  src="$REPO_DIR/config/$f"
  dst="$HERMES_HOME/$f"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    ok "seeded $dst"
  elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
    warn "$dst already exists and differs from the bundle"
    warn "  diff: diff -u \"$src\" \"$dst\""
    warn "  apply: cp \"$src\" \"$dst\""
  else
    ok "$dst is up to date"
  fi
done

bold "3. Linking bundled skills..."
ln -sfn "$REPO_DIR/skills" "$HERMES_HOME/skills/ivx-deployment"
ok "$HERMES_HOME/skills/ivx-deployment → $REPO_DIR/skills"

bold "4. Verifying our external skill repos exist..."
for d in \
  "$HOME/dev/intelli-verse-x-agent-skills/skills" \
  "$HOME/dev/Intelli-verse-X-SDK/skills" \
  "$HOME/dev/agent-skills/.agents/skills" \
  "$HOME/dev/Agentic-SEO-Skill/resources/skills" \
  "$HOME/dev/geo-optimizer-skill/src/geo_optimizer/skills" \
  "$HOME/dev/hyperframes/skills"
do
  if [ -d "$d" ]; then
    ok "external skill dir: $d"
  else
    warn "external skill dir missing: $d (Hermes will silently skip)"
  fi
done

bold "5. Verifying CLI tools required by MCP servers..."
# These are spawned as stdio MCP subprocesses; if missing, comment out that
# server in ~/.hermes/config.yaml or install the CLI.
for cli in gt bd firecrawl npx uvx; do
  if command -v "$cli" >/dev/null 2>&1; then
    ok "$cli: $(command -v $cli)"
  else
    warn "$cli not on PATH — comment out the matching mcp_server in ~/.hermes/config.yaml, or install it"
    case "$cli" in
      gt|bd)      warn "  install: clone intelli-verse-x/gastown (or intelli-verse-x/beads), run 'make install'" ;;
      firecrawl)  warn "  install: npm i -g firecrawl-cli && firecrawl login --browser" ;;
      uvx)        warn "  install: brew install uv  (or pipx)" ;;
      npx)        warn "  install: install Node 20+ via brew or volta" ;;
    esac
  fi
done

bold "6. Checking required env vars..."
ENV_FILE="$HERMES_HOME/.env"
if [ ! -f "$ENV_FILE" ]; then
  cp "$REPO_DIR/config/.env.example" "$ENV_FILE"
  ok "seeded $ENV_FILE from .env.example"
  warn "edit $ENV_FILE and fill in LITELLM_API_KEY, DISCORD_BOT_TOKEN, etc."
else
  ok ".env already exists at $ENV_FILE"
fi

bold "Done."
echo
echo "Next steps:"
echo "  1) Edit ~/.hermes/.env and fill the keys (LITELLM_API_KEY at minimum)."
echo "  2) Run: hermes doctor    # checks config + connectivity"
echo "  3) Run: hermes           # start chatting"
echo
echo "Discord gateway:"
echo "  hermes gateway setup     # interactive setup"
echo "  hermes gateway start     # run the bot"
echo
echo "More: docs/operating-runbook.md in this repo"
