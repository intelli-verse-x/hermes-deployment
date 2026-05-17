# Hermes Agent — intelli-verse-x image.
#
# Builds on top of the official hermes-agent build, with:
#   - Our `gt` binary + `bd` binary so the gt/bd MCP servers work.
#   - Our config bundle (config.yaml + AGENTS.md) copied into the image.
#   - Our bundled skills under /opt/hermes/skills-ivx/ (mounted as an
#     external skill dir at runtime).
#
# Stage 1: build the upstream image so we inherit its install steps.
ARG HERMES_REF=v0.14.0
FROM ghcr.io/nousresearch/hermes-agent:${HERMES_REF} AS hermes-base

# Stage 2: pull our binaries from the gastown / beads ECR images.
FROM 970547373533.dkr.ecr.us-east-1.amazonaws.com/gastown:latest AS gastown-bin
FROM 970547373533.dkr.ecr.us-east-1.amazonaws.com/beads:latest AS beads-bin

# Stage 3: the real image.
FROM hermes-base AS runtime

USER root

# bring in gt + bd so the gt-MCP stdio server can spawn.
COPY --from=gastown-bin /app/gastown/gt /usr/local/bin/gt
COPY --from=beads-bin   /app/gastown/bd /usr/local/bin/bd
RUN chmod +x /usr/local/bin/gt /usr/local/bin/bd

# Bundle our skills (read-only external dir).
COPY skills /opt/hermes/skills-ivx/

# Bundle the config (copied by entrypoint into /opt/data/.hermes/ on first boot).
COPY config/config.yaml /opt/hermes/config-bundle/config.yaml
COPY config/AGENTS.md   /opt/hermes/config-bundle/AGENTS.md

# Entrypoint: first-boot copy + delegate to the upstream entrypoint.
COPY scripts/entrypoint.sh /opt/hermes/bin/entrypoint.sh
RUN chmod +x /opt/hermes/bin/entrypoint.sh

# Re-drop to the hermes user (matches upstream behavior).
USER hermes

ENTRYPOINT ["/opt/hermes/bin/entrypoint.sh"]
CMD ["hermes", "gateway", "start", "--foreground"]
