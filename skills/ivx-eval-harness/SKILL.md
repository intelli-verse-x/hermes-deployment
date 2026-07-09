---
name: ivx-eval-harness
description: "Build and run eval harnesses and agent-loop engineering experiments: define a task suite, run models/prompts/tools through LiteLLM, score results, and iterate."
version: 1.0.0
author: Intelliverse-X
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Evals, Harness, Loop-Engineering, LiteLLM, Benchmarks]
    related_skills: [systematic-debugging, test-driven-development]
---

# Eval harness & loop engineering

Use this skill when asked to "eval", "benchmark", "harness", "A/B prompts",
"compare models", or "tune an agent loop" for anything in the Intelliverse-X
stack (copilot prompts, portal skills, MCP tool loops, game content
pipelines).

## Ground rules

- All model calls go through the LiteLLM gateway (`base_url` in
  `~/.hermes/config.yaml`, key in `~/.hermes/.env`). Never call providers
  directly — LiteLLM gives us spend tracking and Langfuse traces for every
  eval run, which IS the observability layer for comparing runs.
- Keep harness code + datasets in `~/hermes-workspace/evals/<name>/` so runs
  are reproducible and diffable. One folder per experiment.
- List every model id with the gateway (`GET /v1/models`) instead of
  hardcoding — the fleet changes.

## Workflow

1. **Define the task suite first.** A JSONL file of cases:
   `{"id", "input", "expected", "tags"}`. 10–30 cases beats 3. Pull real
   examples from the domain (support tickets from Chatwoot MCP, quiz items
   from nakama, campaign copy from Notifuse) rather than inventing them.
2. **Write the runner.** A small Python script (or notebook via the
   jupyter-live-kernel skill) that loops cases × variants
   (model / prompt / toolset), calls LiteLLM's OpenAI-compatible
   `/v1/chat/completions`, and records
   `{case_id, variant, output, latency_ms, usage}` to `results.jsonl`.
3. **Score.** Prefer deterministic checks (exact/regex/JSON-schema,
   assertion functions). Use LLM-as-judge only for open-ended outputs, with
   a cheap judge model and a rubric written BEFORE seeing outputs.
4. **Report.** Aggregate to a small table: variant × (pass rate, mean
   latency, cost from usage). Print the 3 worst failures verbatim — that is
   where the next loop iteration comes from.
5. **Iterate the loop, not just the prompt.** For agent/tool loops, vary one
   thing at a time: system prompt, tool subset, max steps, model. Re-run the
   SAME suite. Keep a `CHANGELOG.md` in the experiment folder recording each
   variant and its scores.
6. **Ship the winner.** Promote winning prompts into a SKILL.md (user-level
   skill first, then publish to the portal catalog so the whole team gets
   it) or into the relevant repo, with the eval folder linked for evidence.

## Pitfalls

- Don't eval on the cases you tuned on — hold some out.
- Latency/cost regressions count as failures; report them alongside quality.
- If two variants tie, prefer the cheaper/faster one.
