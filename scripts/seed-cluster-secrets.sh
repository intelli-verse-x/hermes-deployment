#!/usr/bin/env bash
#
# seed-cluster-secrets.sh — create/update the `hermes-secrets` k8s secret in
# the `aicart` namespace by pulling from existing cluster secrets.
#
# What it does:
#   - LITELLM_API_KEY ← from litellm-master-key secret
#   - DISCORD_BOT_TOKEN ← from n8n deployment env (we share the bot)
#   - FIRECRAWL_API_KEY ← prompts you (no cluster secret yet)
#   - DISCORD_ALLOWED_USERS ← prompts you
#
# Idempotent: re-running just updates the secret.
set -euo pipefail

NS=aicart

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
die()  { printf "  \033[31m✗\033[0m %s\n" "$*"; exit 1; }

bold "1. Reading LiteLLM master key..."
LITELLM_API_KEY=$(kubectl get secret litellm-master-key -n $NS -o jsonpath='{.data.key}' 2>/dev/null | base64 -d) || \
  die "litellm-master-key secret not found in $NS namespace"
ok "got LITELLM_API_KEY (${#LITELLM_API_KEY} chars)"

bold "2. Reading shared Discord bot token from n8n..."
DISCORD_BOT_TOKEN=$(kubectl exec -n $NS deploy/n8n -- printenv DISCORD_BOT_TOKEN 2>/dev/null || true)
if [ -z "$DISCORD_BOT_TOKEN" ]; then
  read -r -p "  n8n didn't expose DISCORD_BOT_TOKEN — paste it here: " DISCORD_BOT_TOKEN
fi
[ -n "$DISCORD_BOT_TOKEN" ] || die "DISCORD_BOT_TOKEN is required"
ok "got DISCORD_BOT_TOKEN"

bold "3. Discord allowlist..."
read -r -p "  comma-separated Discord user IDs allowed to DM the bot: " DISCORD_ALLOWED_USERS
[ -n "$DISCORD_ALLOWED_USERS" ] || warn "no allowlist set — anyone with the bot link can DM"

bold "4. Firecrawl API key..."
EXISTING_FC=$(kubectl get secret hermes-secrets -n $NS -o jsonpath='{.data.FIRECRAWL_API_KEY}' 2>/dev/null | base64 -d 2>/dev/null || true)
if [ -n "$EXISTING_FC" ]; then
  FIRECRAWL_API_KEY="$EXISTING_FC"
  ok "reusing existing FIRECRAWL_API_KEY"
else
  read -r -p "  FIRECRAWL_API_KEY (blank to skip): " FIRECRAWL_API_KEY
fi

bold "5. Content Factory MCP token..."
EXISTING_CF=$(kubectl get secret hermes-secrets -n $NS -o jsonpath='{.data.CONTENT_FACTORY_MCP_TOKEN}' 2>/dev/null | base64 -d 2>/dev/null || true)
if [ -n "$EXISTING_CF" ]; then
  CONTENT_FACTORY_MCP_TOKEN="$EXISTING_CF"
  ok "reusing existing CONTENT_FACTORY_MCP_TOKEN"
else
  read -r -p "  CONTENT_FACTORY_MCP_TOKEN (blank to skip): " CONTENT_FACTORY_MCP_TOKEN
fi

bold "6. Writing hermes-secrets..."
kubectl create secret generic hermes-secrets -n $NS \
  --from-literal=LITELLM_API_KEY="$LITELLM_API_KEY" \
  --from-literal=DISCORD_BOT_TOKEN="$DISCORD_BOT_TOKEN" \
  ${DISCORD_ALLOWED_USERS:+--from-literal=DISCORD_ALLOWED_USERS="$DISCORD_ALLOWED_USERS"} \
  ${FIRECRAWL_API_KEY:+--from-literal=FIRECRAWL_API_KEY="$FIRECRAWL_API_KEY"} \
  ${CONTENT_FACTORY_MCP_TOKEN:+--from-literal=CONTENT_FACTORY_MCP_TOKEN="$CONTENT_FACTORY_MCP_TOKEN"} \
  --dry-run=client -o yaml | kubectl apply -f -
ok "hermes-secrets up to date"

bold "Done. Next:"
echo "  kubectl apply -f k8s/"
echo "  kubectl rollout status -n $NS deploy/hermes"
