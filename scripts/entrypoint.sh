#!/usr/bin/env bash
#
# Hermes Agent — intelli-verse-x entrypoint.
#
# Runs on every container start. Idempotent.
#   1. Ensures /opt/data/.hermes/ exists (the PVC mount).
#   2. Copies our config bundle into it if not already present (first boot
#      or after the user blew it away). User edits to ~/.hermes/config.yaml
#      survive container restarts because they live in the PVC.
#   3. Updates the bundled-skills external dir to point at /opt/hermes/skills-ivx.
#   4. Hands off to the upstream entrypoint.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-/opt/data/.hermes}"
BUNDLE="${BUNDLE:-/opt/hermes/config-bundle}"

mkdir -p "$HERMES_HOME"

# Copy config bundle on first boot (don't overwrite user edits).
for f in config.yaml AGENTS.md; do
  if [ ! -f "$HERMES_HOME/$f" ] && [ -f "$BUNDLE/$f" ]; then
    cp "$BUNDLE/$f" "$HERMES_HOME/$f"
    echo "[hermes-entrypoint] seeded $HERMES_HOME/$f from bundle"
  fi
done

# Symlink the bundled skills into the user's external_dirs path. This is
# more reliable than depending on the user's $HOME being right.
mkdir -p "$HERMES_HOME/external-skills"
ln -sfn /opt/hermes/skills-ivx "$HERMES_HOME/external-skills/ivx-deployment"

# Pre-write a minimal SOUL.md if the user doesn't have one. They can edit.
if [ ! -f "$HERMES_HOME/SOUL.md" ]; then
  cat > "$HERMES_HOME/SOUL.md" <<'EOF'
# Hermes — intelli-verse-x persona

You are the conversational AI for intelli-verse-x. You're terse,
practical, and bias-to-action. You file beads, dispatch work, ship
artifacts, then talk in plain language.

You never carry agent-to-agent state in prose — Beads is the source
of truth.
EOF
  echo "[hermes-entrypoint] seeded SOUL.md"
fi

# Hand off to the upstream entrypoint if it exists; otherwise just exec.
if [ -x /opt/hermes/docker/entrypoint.sh ]; then
  exec /opt/hermes/docker/entrypoint.sh "$@"
fi
exec "$@"
