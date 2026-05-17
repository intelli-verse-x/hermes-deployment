# Hermes Agent best-practices (cited)

Where this differs from the README, this wins. All citations from the
official Hermes docs (firecrawl-pulled May 2026) plus our 2026
architecture canvases.

## 1. Configure ONE inference provider; use `fallback_models` for redundancy

> "Hermes supports a `fallback_models` chain. If the primary model
> rate-limits or fails, Hermes drops to the next."
> — [Configuration docs](https://hermes-agent.nousresearch.com/docs/user-guide/configuration)

We point all of Hermes at **LiteLLM** as the single `provider: custom`
endpoint. Inside LiteLLM we configure 3 upstream providers
(Anthropic, OpenAI, OpenRouter). Hermes doesn't need to know about any
of them — LiteLLM handles routing + per-team budgets + Langfuse
tracing.

**Why this matters**: every other agent in our stack (Mayor, Refinery,
Witness, the certification fleet, the polecats) already uses LiteLLM.
Putting Hermes on the same gateway means spend tracking, observability,
and rate-limit handling are uniform across the stack.

## 2. Use external skill dirs, not skill copies

> "External dirs are only scanned for skill discovery. When the agent
> creates or edits a skill, it always writes to `~/.hermes/skills/`."
> — [Skills docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills#external-skill-directories)

We point at 7 external dirs (every skill repo we have). When Hermes
learns something new during a session, it writes locally — so the
external repos stay clean for git-based collaboration. To promote a
locally-created skill to a "permanent" team skill, commit it to one of
the external repos and Hermes will start reading from there.

## 3. Memory is for *you*, not for state passed between agents

> "memory — Agent's Personal Notes ... user — User Profile"
> — [Memory docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory#two-targets-explained)

Hermes memory is for the Hermes process itself. **Cross-agent state
goes in Beads**, not in memory. This is enforced by the
`bd close` policy gate (`beads#1`) and the Slim Mayor Doctrine in
`gastown/internal/templates/roles/mayor.md.tmpl`.

## 4. Filter MCP tools per server

> "If you have a server with 50 tools, but only need 3, list those 3
> under `allow`. Everything else is filtered out before Hermes sees it."
> — [MCP per-server filtering](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp#per-server-filtering)

Tool bloat is a real failure mode — Vercel's 2026 study found removing
80% of tools improved task completion. We don't allowlist by default
(Hermes is meant to be exploratory), but for production Discord-bot use
we recommend an `allow:` list per server. Example for the Discord
gateway (paste into `~/.hermes/config.yaml`):

```yaml
mcp_servers:
  content-factory:
    allow:
      - list_pipelines
      - run_pipeline
      - get_task_status
      - get_artifacts
  gt:
    allow:
      - status
      - bd_create
      - bd_show
      - bd_ready
      - sling
      - mail_send
      - mail_inbox
      - nudge
      - escalate
```

## 5. Cron is for unattended automation, not for ad-hoc tasks

> "Built-in cron scheduler with delivery to any platform. Daily reports,
> nightly backups, weekly audits — all in natural language."
> — [Cron docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron)

Examples of good cron uses for our stack:

- Daily `bd ready` digest posted to Discord
- Weekly `bv --robot-insights` PageRank/cycle report
- Nightly Langfuse cost summary posted to Discord
- Weekly stale-bead audit (`bd list --status open --updated-before 7d ago`)

These should live in cron, not in n8n. (n8n is for event-driven
workflows; cron is for time-based agent kicks where you want a
conversational summary.)

## 6. Discord-gateway sessions are per-user, NOT per-channel

> "Each Discord user gets their own session that persists across DMs,
> mentions, and channel messages. Channel mentions share the channel's
> session unless DM-pairing is enabled."
> — [Discord docs](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/discord#session-model-in-discord)

Cost implication: if 10 users DM the bot, you have 10 long-running
sessions, each holding context. Use `/reset` aggressively if a session
drifts off-topic. The Hermes curator handles compression but only at
configured intervals.

## 7. Use the OpenAI-compatible API server for programmatic access

> "Hermes ships an OpenAI-compatible API server. Other tools (Cursor,
> Continue, etc.) can talk to it just like they would talk to OpenAI."
> — [API server docs](https://hermes-agent.nousresearch.com/docs/reference/api-server)

For our use case: any in-cluster service that already speaks OpenAI's
wire format can route through Hermes (and pick up its memory + skills +
MCP tools) by pointing at `https://hermes-api.intelli-verse-x.ai`.
This is how we wire Hermes into bigger Bernstein crews later.

## 8. Run `hermes doctor` after every config change

`hermes doctor` validates:
- `model` config (provider + base_url + api_key)
- MCP server registration (each is `pingable`)
- Skills index (every `SKILL.md` parses)
- Memory.db schema
- Gateway connectivity

It's the cheap, fast check before you blame a deeper issue.

---

## Anti-patterns to avoid

| Don't | Why | Do this instead |
|---|---|---|
| Use Hermes memory to pass state to another agent | Memory is local to this Hermes; the other agent can't read it. | File a bead and let both agents read it. |
| Hardcode model names in skills | LiteLLM routes by name; if we rename a model upstream, every skill breaks. | Reference roles ("the cheapest fast model"), not names. |
| Run media-generation primitives in a tight loop | Wastes GPU credits + no pipeline-level resumability. | Use a named CF pipeline. |
| Edit skills under `external_dirs` from Hermes | Hermes can't write there — confusing errors. | Edit in the external repo, `git pull` locally. |
| Expose the dashboard publicly without an OAuth proxy | The dashboard stores API keys in plaintext. | Cloudflare Access or `127.0.0.1` + SSH tunnel. |
| Run two Hermes pods against the same PVC | SQLite memory.db doesn't support concurrent writers. | One pod, one PVC. Scale per-tenant if you need multiple. |
