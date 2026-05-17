# Hermes Agent — operating runbook

This runbook covers day-to-day operation of our self-hosted Hermes
Agent. Cited best practices below come from the official Hermes docs
([hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs))
plus our 2026 architecture canvases.

## Two ways to run it

### A. Local on your laptop (the common case)

```bash
git clone git@github.com:intelli-verse-x/hermes-deployment.git
cd hermes-deployment
./scripts/install-local.sh
# edit ~/.hermes/.env with your LITELLM_API_KEY etc.
hermes doctor
hermes
```

Hermes ships a TUI with multiline editing, slash-command autocomplete,
streaming tool output, and conversation history — see
[CLI usage](https://hermes-agent.nousresearch.com/docs/user-guide/cli).

### B. Self-hosted in our k8s cluster (Discord gateway)

```bash
# 1) Build + push the image (CI does this on tag).
docker buildx build --platform linux/amd64 \
  -t 970547373533.dkr.ecr.us-east-1.amazonaws.com/hermes-agent:latest \
  --push .

# 2) Make sure the configmap is up to date.
kubectl create configmap hermes-config-bundle -n aicart \
  --from-file=config.yaml=config/config.yaml \
  --from-file=AGENTS.md=config/AGENTS.md \
  --dry-run=client -o yaml | kubectl apply -f -

# 3) Make sure the secret has DISCORD_BOT_TOKEN + LITELLM_API_KEY.
kubectl create secret generic hermes-secrets -n aicart \
  --from-literal=LITELLM_API_KEY="$(kubectl get secret litellm-master-key -n aicart -o jsonpath='{.data.key}' | base64 -d)" \
  --from-literal=DISCORD_BOT_TOKEN="$(kubectl exec -n aicart deploy/n8n -- printenv DISCORD_BOT_TOKEN)" \
  --from-literal=FIRECRAWL_API_KEY="..." \
  --from-literal=DISCORD_ALLOWED_USERS="your-discord-id" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4) Deploy.
kubectl apply -f k8s/

# 5) Watch.
kubectl logs -n aicart deploy/hermes -f
```

The pod boots → the entrypoint seeds config → Hermes loads MCP servers →
gateway connects to Discord. DM the bot or @-mention it in your channel.

## How the pieces wire together

```
┌──────────────────────────────┐
│   Discord (humans)           │
└─────────────┬────────────────┘
              │
       ▼ messaging-gateway
┌──────────────────────────────┐
│   Hermes Agent (this pod)    │
│   - TUI / API / Gateway       │
│   - Memory.db, sessions       │
│   - Skills (8+ external dirs) │
└─────────────┬────────────────┘
              │ MCP servers
   ┌──────────┼──────────────────────────────────┐
   ▼          ▼              ▼          ▼        ▼
┌─────┐  ┌──────────┐  ┌─────────┐  ┌──────┐  ┌───────────────┐
│ gt  │  │ leantime │  │ content │  │ n8n  │  │ firecrawl     │
│ MCP │  │ MCP      │  │ factory │  │ MCP  │  │ filesystem    │
│     │  │          │  │ MCP     │  │      │  │ intelli-verse │
└──┬──┘  └────┬─────┘  └────┬────┘  └──┬───┘  └───────────────┘
   │          │             │          │
   ▼          ▼             ▼          ▼
 Beads     Leantime      ECR/GPU     Workflows
 (Dolt)    + MySQL       pipelines   (Postgres)
              │
              ▼
         ALL LLM CALLS
              │
              ▼
┌──────────────────────────────┐
│   LiteLLM gateway            │ ── traces ──→ Langfuse
│   - virtual keys / budgets   │
└─────────────┬────────────────┘
              │
   Anthropic / OpenAI / OpenRouter / etc.
```

## Best-practices, with citations

### 1. Use `external_dirs` for shared skills

> "If you maintain skills outside of Hermes — for example, a shared
> `~/.agents/skills/` directory used by multiple AI tools — you can tell
> Hermes to scan those directories too. Add `external_dirs` under the
> `skills` section in `~/.hermes/config.yaml`."
> — [Skills docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills#external-skill-directories)

We point at **seven** external dirs so every skill repo we maintain
shows up in Hermes's skill index automatically. Hermes only writes to
`~/.hermes/skills/`, so external dirs stay clean.

### 2. Prefix every MCP tool by server

> "Hermes prefixes MCP tools so they do not collide with built-in names:
> `mcp_<server_name>_<tool_name>`"
> — [MCP docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp#how-hermes-registers-mcp-tools)

In `AGENTS.md` we reference everything as `mcp_gt_*`, `mcp_leantime_*`,
etc. so Hermes never confuses our tools with built-ins.

### 3. Whitelist tools per server when bloat hits

> "If you have a server with 50 tools, but only need 3, list those 3
> under `allow`. Everything else is filtered out before Hermes sees it."
> — [MCP per-server filtering](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp#per-server-filtering)

When `content-factory` exposes ~50 pipelines and we only want the user
to use a subset for a given session, add an `allow:` list under that
server. We **don't** ship default whitelists because the right subset
depends on the role; instead the `ivx-content-factory` skill documents
how to switch toolsets.

### 4. Memory is local; beads is shared

> "When the agent figures out a non-trivial workflow, it saves the
> approach as a skill for future reuse."
> — [Memory docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory)

Our convention (encoded in AGENTS.md): user-specific knowledge → memory
(local, search-able), agent work → beads (cross-agent ground truth).

### 5. Cross-provider review at the agent boundary

> "OpenAI shipped `codex-plugin-cc` for Claude Code in April 2026 — exactly
> what the literature calls *cross-provider adversarial review*."

We mirrored this with the cross-provider PR review GitHub Action
(`pr-cross-review.yml`) in `gastown#5` and `beads#2`. Hermes can call
both Claude and Codex through LiteLLM, so when it asks itself to review
its own output it gets a second-provider opinion for free.

## Daily ops

```bash
# Is the pod healthy?
kubectl get pod -n aicart -l app=hermes

# Tail logs
kubectl logs -n aicart deploy/hermes -f

# Restart (preserves memory + skills via PVC)
kubectl rollout restart deploy/hermes -n aicart

# Shell in (for debugging)
kubectl exec -n aicart deploy/hermes -it -- bash

# Check what MCP servers are loaded
kubectl exec -n aicart deploy/hermes -- hermes doctor

# Manually rebuild config from this repo
kubectl create configmap hermes-config-bundle -n aicart \
  --from-file=config.yaml=config/config.yaml \
  --from-file=AGENTS.md=config/AGENTS.md \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deploy/hermes -n aicart
```

## Upgrading

```bash
# 1) Bump the upstream Hermes pin in Dockerfile (ARG HERMES_REF=v0.X.Y)
# 2) Rebuild + push the image
docker buildx build --platform linux/amd64 \
  -t 970547373533.dkr.ecr.us-east-1.amazonaws.com/hermes-agent:v0.X.Y \
  -t 970547373533.dkr.ecr.us-east-1.amazonaws.com/hermes-agent:latest \
  --push .
# 3) kubectl rollout restart -n aicart deploy/hermes
```

Memory + sessions + config survive upgrades because they live on the
`hermes-data` PVC. The image only ships the binary + the bundled config
+ our skills.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Pod CrashLoopBackOff | Missing `LITELLM_API_KEY` or `DISCORD_BOT_TOKEN` | Recreate `hermes-secrets` with both. |
| `gt` MCP server fails to start | `gt` binary not in image | Re-pull `gastown:latest` and rebuild. |
| Bot doesn't respond on Discord | `DISCORD_ALLOWED_USERS` missing your ID | Add your Discord user ID. |
| `Provider error: 401` | Wrong LiteLLM key | `kubectl get secret litellm-master-key -n aicart -o jsonpath='{.data.key}' \| base64 -d` and re-seed. |
| `Tool list empty` | All MCP servers failed to register | `hermes doctor`; check each `command` exists in PATH. |
| Skill not appearing | External dir doesn't exist on box | Either clone the repo to the expected path, or remove that entry from `external_dirs`. |

## Where the costs are

- **GPT-5 / Claude tokens** — flows through LiteLLM. Per-team budgets
  applied there. Hermes itself doesn't charge.
- **Storage** — `hermes-data` PVC: 10 Gi gp2. Memory.db rarely exceeds
  500 MB; session history is the bulk.
- **GPU compute** — only when you call `content-factory` pipelines.
  Tracked in the CF dashboard.
