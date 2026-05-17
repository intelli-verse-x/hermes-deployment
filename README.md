# hermes-deployment

Self-hosted [Hermes Agent](https://github.com/NousResearch/hermes-agent)
configured for the **intelli-verse-x** 5-layer agentic stack. This repo
holds:

- **`config/config.yaml`** — Hermes config pre-wired to LiteLLM, Beads/Gas
  Town, Leantime MCP, Content Factory MCP, n8n, Firecrawl, and our 7
  external skill repos.
- **`config/AGENTS.md`** — the context file Hermes auto-loads, mapping
  the stack so Hermes knows what every service is.
- **`skills/`** — bundled skills that ship with the deployment:
  `ivx-stack-tour`, `ivx-products-tour`, `ivx-content-factory`,
  `ivx-gastown-bridge`.
- **`k8s/`** — Kubernetes manifest for the Discord-gateway pod
  (deployment + service + ingress + configmap).
- **`scripts/install-local.sh`** — one-command local install for laptops.
- **`scripts/entrypoint.sh`** — k8s entrypoint that seeds the PVC from
  the bundled config on first boot.
- **`docs/`** — operating runbook + best-practices with citations.

---

## What is Hermes, in 30 seconds

Hermes is "the agent that grows with you" — built by Nous Research, MIT
license, 155k GitHub stars. Three properties matter for our stack:

1. **Self-improving** — creates skills from experience, FTS5 session
   search, persistent memory, dialectic user modeling
   ([Honcho](https://github.com/plastic-labs/honcho)).
2. **Lives where you do** — Discord, Telegram, Slack, WhatsApp, Signal,
   Email, CLI — all from one gateway process.
3. **MCP-native** — every tool plugs in via MCP; perfect fit for our
   existing MCP servers (gt, leantime, content-factory, n8n, firecrawl).

In our 5-layer stack Hermes sits on top, as **the user-facing
conversational AI** that turns plain-English asks into bead-tracked work.

---

## Quick start

### Local (your laptop)

```bash
git clone git@github.com:intelli-verse-x/hermes-deployment.git
cd hermes-deployment
./scripts/install-local.sh
# edit ~/.hermes/.env (at minimum: LITELLM_API_KEY)
hermes doctor
hermes
```

### k8s (cluster Discord bot)

```bash
# build + push
docker buildx build --platform linux/amd64 \
  -t 970547373533.dkr.ecr.us-east-1.amazonaws.com/hermes-agent:latest --push .

# seed configmap
kubectl create configmap hermes-config-bundle -n aicart \
  --from-file=config.yaml=config/config.yaml \
  --from-file=AGENTS.md=config/AGENTS.md \
  --dry-run=client -o yaml | kubectl apply -f -

# seed secrets (pulls from existing cluster secrets where possible)
./scripts/seed-cluster-secrets.sh

# deploy
kubectl apply -f k8s/
kubectl rollout status -n aicart deploy/hermes
```

DM the bot, or `@hermes` in a channel.

---

## How Hermes plugs into the rest of the stack

| Layer | Service | How Hermes uses it |
|---|---|---|
| 1 Strategy | Leantime | `mcp_leantime_*` tools — list/create/update tickets. |
| 1 Strategy | GitHub | Via `gh` CLI in shell tools (no MCP needed). |
| 2 Coordination | Beads (`bd`) | `mcp_gt_bd_*` tools — file/show/close beads. |
| 2 Coordination | Bernstein | Hermes dispatches via `gt sling`; Bernstein owns the per-project crew. |
| 3 Multi-project | Gas Town | `mcp_gt_*` for status / rigs / mail / nudges. |
| 4 Platform | LiteLLM | **All** LLM calls; configured as Hermes's `provider: custom`. |
| 4 Platform | Infisical | Optional Hermes secret backend via `INFISICAL_MACHINE_IDENTITY_TOKEN`. |
| 4 Platform | Langfuse | Automatic — LiteLLM forwards traces (no Hermes config). |
| 5 Glue | n8n | `mcp_n8n_*` for workflow triggers (gt-escalate → Discord etc.). |
| 5 Glue | GitHub Actions | Via `gh` CLI; cross-provider review via the workflow. |

---

## Repo map

```
hermes-deployment/
├── README.md                          # you are here
├── Dockerfile                         # image: official hermes + our binaries + bundle
├── config/
│   ├── config.yaml                    # pre-wired Hermes config (MCP, model, skills, memory)
│   ├── AGENTS.md                      # auto-loaded context map for Hermes
│   └── .env.example                   # secrets template
├── skills/                            # bundled SKILL.md files for the deployment
│   ├── ivx-stack-tour/SKILL.md
│   ├── ivx-products-tour/SKILL.md
│   ├── ivx-content-factory/SKILL.md
│   └── ivx-gastown-bridge/SKILL.md
├── k8s/                               # cluster deployment
│   ├── deployment.yaml
│   ├── ingress.yaml
│   └── configmap.yaml
├── scripts/
│   ├── install-local.sh               # one-command laptop install
│   └── entrypoint.sh                  # k8s container entrypoint
└── docs/
    ├── operating-runbook.md           # day-to-day ops
    └── best-practices.md              # cited best practices
```

---

## Why we forked

The official `NousResearch/hermes-agent` is upstream-of-truth. We fork
into `intelli-verse-x/hermes-agent` for:

1. **Reproducible builds** — pin a specific upstream tag in our
   Dockerfile so cluster rollouts can't drift.
2. **In-house plugins** — when we write a Hermes plugin (e.g., a custom
   memory provider that reads from our Beads dolt remote), it lives in
   the fork. Patches we want upstream we PR back.
3. **Patch independence** — security-fix flexibility without waiting on
   upstream merge cycles.

This `hermes-deployment` repo is the **operational glue**. Day-to-day
work happens here (config, manifests, runbooks). The fork is the binary
substrate.

---

## Where Hermes fits in our 30-day rollout

Rolled out alongside the `hq-2mq` 30-day plan:

| Week | Existing rollout item | Hermes contribution |
|---|---|---|
| W1 | Leantime + MCP + LiteLLM + Infisical (live) | Hermes uses every one of these. |
| W2 | Claude Squad + Bernstein + Slim Mayor | Hermes IS the slim user-facing layer the mayor work was about. |
| W3 | Langfuse + Agent Vault | Hermes auto-traces via LiteLLM → Langfuse; reads secrets via Infisical. |
| W4 | n8n flows + GitHub Actions CI | Hermes triggers n8n flows via MCP; n8n delivers Discord pings to Hermes users. |

Filing this work as a bead under the rollout epic (see
`docs/operating-runbook.md`).

---

## License

This config repo: MIT. Hermes Agent itself: MIT (NousResearch).

---

## Citations

- [Hermes docs root](https://hermes-agent.nousresearch.com/docs)
- [MCP integration](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp)
- [Skills system](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills)
- [Memory](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory)
- [Discord gateway](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/discord)
- [Configuration](https://hermes-agent.nousresearch.com/docs/user-guide/configuration)
- [Context files (AGENTS.md, SOUL.md)](https://hermes-agent.nousresearch.com/docs/user-guide/features/context-files)

All firecrawl-pulled to `.firecrawl/` in `~/dev/hermes-agent/` (the
upstream fork checkout) for offline reference.
