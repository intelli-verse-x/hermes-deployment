#!/usr/bin/env bash
#
# install-claude-squad.sh — installer for Claude Squad on macOS.
#
# Claude Squad is host-side: it's a TUI that drives multiple Claude-Code
# sessions in parallel from your terminal. It cannot run in a pod, it
# wants your local tmux + your Claude Code login state.
#
# This script:
#   1. brew installs claude-squad
#   2. drops a minimal config at ~/.claude-squad/config.yaml pointing at
#      our LiteLLM gateway, so spend tracking captures squad usage too.
#   3. seeds the default sessions you'd want for our 5-layer stack.
#
# Run on your Mac:
#   bash /Users/devashishbadlani/dev/hermes-deployment/scripts/install-claude-squad.sh
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }

bold "1. Homebrew check..."
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found. Install from https://brew.sh first."
  exit 1
fi
ok "brew: $(command -v brew)"

bold "2. claude-squad install..."
if command -v cs >/dev/null 2>&1 || brew list claude-squad >/dev/null 2>&1; then
  ok "already installed; running brew upgrade"
  brew upgrade claude-squad 2>&1 | tail -3 || true
else
  brew install claude-squad 2>&1 | tail -5
  ok "installed: $(command -v cs || echo claude-squad)"
fi

bold "3. tmux check..."
if ! command -v tmux >/dev/null 2>&1; then
  warn "tmux missing — claude-squad needs it. Installing..."
  brew install tmux 2>&1 | tail -3
fi
ok "tmux: $(tmux -V)"

bold "4. Claude Code check..."
if ! command -v claude-code >/dev/null 2>&1; then
  warn "claude-code CLI missing — claude-squad wraps it."
  warn "Install: npm i -g @anthropic-ai/claude-code  (or brew install claude-code)"
else
  ok "claude-code: $(command -v claude-code)"
fi

bold "5. Drop initial config..."
CS_HOME="$HOME/.claude-squad"
mkdir -p "$CS_HOME"
if [ -f "$CS_HOME/config.yaml" ]; then
  ok "config.yaml already exists at $CS_HOME — leaving alone"
else
  cat > "$CS_HOME/config.yaml" <<'EOF'
# Claude Squad — intelli-verse-x default config.
#
# Routes all model calls through LiteLLM so spend tracking captures
# claude-squad sessions in the same dashboard as everything else.
#
# Squad sessions are host-side: they drive your local claude-code,
# which talks to LiteLLM via OPENAI_API_KEY + OPENAI_BASE_URL.

inference:
  base_url: "https://litellm.intelli-verse-x.ai/v1"
  # api_key: read from env  LITELLM_API_KEY  (mirror to OPENAI_API_KEY).
  default_model: "anthropic/claude-opus-4.6"
  fallback:
    - "openai/o3"
    - "openai/gpt-5"

# A starter set of sessions matching our 5-layer stack work.
# Add your own with `cs new <name>` or by appending here.
sessions:
  - name: gastown-dev
    cwd:  ~/dev/gastown
    init: "Review open PRs and ready beads; pick one to tackle."
  - name: hermes-dev
    cwd:  ~/dev/hermes-deployment
    init: "Inventory hermes-deployment for follow-up tasks."
  - name: content-factory
    cwd:  ~/dev/content-factory
    init: "Browse content-factory pipelines; pick one to extend."
  - name: kube-infra
    cwd:  ~/dev/intelli-verse-kube-infra
    init: "Look at cluster manifest gaps; queue beads."

# UI
ui:
  theme: "midnight"
EOF
  ok "wrote $CS_HOME/config.yaml"
fi

bold "6. Bash/zsh: add LITELLM_API_KEY env export..."
SHELLRC="$HOME/.zshrc"
[ -f "$SHELLRC" ] || SHELLRC="$HOME/.bashrc"
if grep -q "LITELLM_API_KEY=" "$SHELLRC" 2>/dev/null; then
  ok "LITELLM_API_KEY already exported in $SHELLRC"
else
  cat >> "$SHELLRC" <<'EOF'

# intelli-verse-x: Claude Squad / Hermes route through LiteLLM
export LITELLM_API_KEY="${LITELLM_API_KEY:-PASTE_FROM_INFISICAL}"
# Mirror so legacy OpenAI-compatible tools pick it up:
export OPENAI_API_KEY="${OPENAI_API_KEY:-$LITELLM_API_KEY}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://litellm.intelli-verse-x.ai/v1}"
EOF
  warn "added LITELLM_API_KEY stub to $SHELLRC — paste the real value:"
  warn "  TOKEN=\$(kubectl get secret infisical-admin -n aicart -o jsonpath='{.data.MACHINE_IDENTITY_TOKEN}' | base64 -d)"
  warn "  PID=\$(curl -fsS -H \"Authorization: Bearer \$TOKEN\" https://infisical.intelli-verse-x.ai/api/v1/workspace | jq -r '.workspaces[]|select(.name==\"hermes\")|.id')"
  warn "  curl -fsS -H \"Authorization: Bearer \$TOKEN\" \\"
  warn "    \"https://infisical.intelli-verse-x.ai/api/v3/secrets/raw/LITELLM_API_KEY?workspaceId=\$PID&environment=prod\" | jq -r .secret.secretValue"
fi

bold "Done. Open a new terminal and run:"
echo "  cs              # launches the squad TUI"
echo
echo "Common keys inside cs:"
echo "  n          new session"
echo "  Enter      jump to session"
echo "  q          quit"
echo
echo "Verify spend tracking: after a few turns, check"
echo "  https://litellm.intelli-verse-x.ai/spend/calculate"
echo "  (the team_id 'mayor' / 'crew' should accumulate spend)"
