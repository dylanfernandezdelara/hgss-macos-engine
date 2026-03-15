---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: "__PROJECT_SLUG__"
  active_states:
    - Todo
    - In Progress
    - Merging
    - Rework
  terminal_states:
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
    - Done
polling:
  interval_ms: 5000
workspace:
  root: $SYMPHONY_WORKSPACE_ROOT
hooks:
  after_create: |
    git clone --depth 1 https://github.com/dylanfernandezdelara/hgss-macos-engine.git .
    ./scripts/bootstrap.sh
agent:
  max_concurrent_agents: 10
  max_turns: 20
codex:
  command: codex --config shell_environment_policy.inherit=all --config model_reasoning_effort=xhigh --model gpt-5.3-codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
---

You are working on Linear issue `{{ issue.identifier }}` for the HGSS macOS engine.

Issue context:
- Identifier: `{{ issue.identifier }}`
- Title: `{{ issue.title }}`
- URL: `{{ issue.url }}`
- State: `{{ issue.state }}`

Description:
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

Repository operating rules:

1. Respect module boundaries:
   - `Apps/HGSSMac` is UI shell only.
   - Runtime game logic belongs in `Sources/HGSSCore` and other package modules.
2. Maintain legal and asset hygiene:
   - Never add ROMs, save files, extracted proprietary assets, or reverse-engineering dumps.
   - Only tiny synthetic fixtures are allowed in git.
3. Keep work scoped to the ticket and produce small, reviewable diffs.
4. Update docs when developer workflow or module boundaries change.
5. Before final handoff, run:
   - `./scripts/check_repo.sh`
   - `./scripts/test.sh`
   - `./scripts/run_extractor_stub.sh`
6. If app shell behavior changed, also run:
   - `./scripts/run_app.sh`
7. Do not ask a human for routine follow-up. Only stop early for true blockers
   (missing required credentials, missing external permissions, or missing required tools).

Execution expectations:

1. Follow this state flow:
   - `Todo` -> move to `In Progress` before implementation.
   - `In Progress` -> use for active implementation.
   - `Human Review` -> wait for human review, do not continue coding unless moved to `Rework`.
   - `Rework` -> address requested changes, then return to `Human Review`.
   - `Merging` -> land approved PR and transition to `Done`.
2. Implement the smallest complete fix that satisfies acceptance criteria.
3. Keep commits coherent and keep PR body aligned to `.github/pull_request_template.md`.
4. Include proof-of-work command summaries in PR/comment output.
5. If blocked by missing required auth/tools, report blocker clearly and stop early.
