# AI Agency — architecture docs site

Static S3 site documenting the architecture of each AI Agency codebase
(`hermes-agent`, `hermes-deployment`, the desktop shells, `agent-skills`)
plus how they wire into the platform.

- Live: https://intelliverse-agency-docs.s3.amazonaws.com/index.html
- Linked from the admin portal (tile `agency-architecture`).

Style assets (`assets/style.css`, `assets/app.js`) are shared with the
intelliverse-llm-docs / intelliverse-skills-docs site family — copy from
either bucket if missing locally.

## Publish

```bash
cd hermes-deployment
aws s3 sync docs/architecture-site s3://intelliverse-agency-docs \
  --delete --exclude "README.md"
```

Keep pages hand-maintained; update when a codebase's architecture changes
(new repo, new deployment shape, new skill mounts).
