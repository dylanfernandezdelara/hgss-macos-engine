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
   - `Human Review` -> only use after review handoff artifacts exist; wait for human review and do not continue coding unless moved to `Rework`.
   - `Rework` -> address requested changes, then return to `Human Review`.
   - `Merging` -> land approved PR and transition to `Done`.
2. Implement the smallest complete fix that satisfies acceptance criteria.
3. Before moving an issue to `Human Review`, make the work reviewable:
   - Verify `git remote get-url origin` points to `https://github.com/dylanfernandezdelara/hgss-macos-engine.git`. If it does not, fix it before pushing.
   - Create or switch to the issue branch. Prefer `{{ issue.branch_name }}` when provided.
   - Commit the intended changes.
   - Push the branch to GitHub `origin`.
   - Open or update a PR against `main`.
   - Add a Linear comment that includes the PR URL, branch name, commit SHA, and proof-of-work summary.
4. If branch push or PR creation cannot be completed, do not move the issue to `Human Review`. Stay in `In Progress` and leave a blocker comment explaining exactly what failed.
5. Keep commits coherent and keep the PR body aligned to `.github/pull_request_template.md`.
6. Include proof-of-work command summaries in PR/comment output.
7. If blocked by missing required auth/tools, report blocker clearly and stop early.
