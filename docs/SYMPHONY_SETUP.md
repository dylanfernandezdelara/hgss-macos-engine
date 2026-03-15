# Symphony Setup

This repository includes a Symphony workflow template and a thin wrapper around the upstream
`openai/symphony` Elixir reference implementation.

## What Was Added

- `Symphony/WORKFLOW.md`: Symphony workflow config + agent prompt for this repo.
- `scripts/run_symphony.sh`: applies repo-local setup, then launches the upstream
  `openai/symphony` Elixir reference implementation with this repo's workflow.

## Prerequisites

1. `codex` CLI available in `PATH` with app-server support.
2. [mise](https://mise.jdx.dev/) installed.
3. Linear personal API key with access to your workspace/project.

## One-Time Environment Setup

Create a local Symphony config file (gitignored):

```bash
cp .symphony.local.env.example .symphony.local.env
# edit .symphony.local.env and set SYMPHONY_LINEAR_PROJECT_SLUG
```

Optional:

```bash
export SYMPHONY_WORKSPACE_ROOT="$HOME/code/symphony-workspaces"
```

Notes:

- To get the project slug in Linear, open the project page URL and copy the slug/id segment after `/project/<name>-`.
- `scripts/run_symphony.sh` reads `SYMPHONY_LINEAR_PROJECT_SLUG` from your shell env or `.symphony.local.env`, then patches `Symphony/WORKFLOW.md` at runtime.
- `LINEAR_API_KEY` is read from your shell env, or from macOS Keychain service `symphony-linear-api-key` when present.
- `SYMPHONY_WORKSPACE_ROOT` is where Symphony creates isolated per-issue workspaces. Those
  workspaces are separate checkouts used for ticket execution; they are not the same thing as the
  foreground terminal where the Symphony service itself is launched.

If you prefer env vars instead of `.symphony.local.env`:

```bash
export SYMPHONY_LINEAR_PROJECT_SLUG=your-linear-project-slug
export LINEAR_API_KEY=lin_api_...
```

## Recommended Linear Workflow States (Required)

Symphony's upstream workflow expects these additional Linear issue states:

- `Rework`
- `Human Review`
- `Merging`

Configure them in Linear:

1. Open **Linear -> Team Settings -> Workflow** for `FDL Studio`.
2. Add `Rework`, `Human Review`, and `Merging` (recommended under the **Started** category).
3. If you currently use `In Review`, either rename it to `Human Review` or keep both and standardize on `Human Review` for Symphony.
4. Keep terminal states including `Done`, `Canceled`/`Cancelled`, and `Duplicate`.

Notes:

- The repo template tracks `Todo`, `In Progress`, `Rework`, and `Merging` as `active_states`.
- `Human Review` is intentionally not an active polling state in Symphony; it acts as the human gate between implementation and merge.

## Run Symphony

The source of truth for how Symphony is launched is the upstream Elixir reference implementation.
Upstream documents Symphony as a foreground service started directly from a shell with `mise exec`:

```bash
mise exec -- ./bin/symphony ./WORKFLOW.md
```

For this repository, use the helper launcher below as a thin wrapper around that same command. It
should not be treated as a different operating model. Its job is to apply repo-local setup and then
hand off to the upstream startup flow.

Intentional repo-local additions:

- reads `.symphony.local.env`
- resolves `LINEAR_API_KEY`
- patches `Symphony/WORKFLOW.md` with the project slug at runtime
- runs the upstream Elixir implementation via `mise exec`
- adds Symphony's required preview acknowledgment flag

Recommended usage:

1. Start Symphony in its own Terminal window or tab.
2. Leave that terminal open while Symphony is running.
3. Stop it with `Ctrl-C` in that terminal.

```bash
./scripts/run_symphony.sh
```

If you want the raw upstream-shaped command after setup, it is:

```bash
cd External/symphony/elixir
mise exec -- ./bin/symphony /path/to/WORKFLOW.md
```

For ticket execution, the upstream model is isolated per-issue workspaces. In this repo that is
implemented in [`Symphony/WORKFLOW.md`](/Users/dylanfdl/Projects/hgss-macos-engine/Symphony/WORKFLOW.md)
with:

```yaml
workspace:
  root: $SYMPHONY_WORKSPACE_ROOT
hooks:
  after_create: |
    git clone --depth 1 https://github.com/dylanfernandezdelara/hgss-macos-engine.git .
```

That is the behavior to align with upstream. `git worktree` is not the documented default in the
official Symphony repo. If you want to use worktrees instead, that would be a repo-specific
customization to `hooks.after_create`, not the baseline recommendation.

The launcher matches upstream dashboard behavior and does not enable the observability UI unless you
pass `--port`.

Raw upstream-equivalent shape:

```bash
cd External/symphony/elixir
mise trust
mise install
mise exec -- mix setup
mise exec -- mix build
mise exec -- ./bin/symphony /path/to/WORKFLOW.md
```

Enable the dashboard explicitly when needed:

```bash
./scripts/run_symphony.sh --port 4000
```

Dashboard URL when `--port 4000` is used:

```text
http://127.0.0.1:4000/
```

Notes:

- `http://localhost:4000/` is equivalent when local hostname resolution behaves normally.
- Do not treat `nohup` as the default run mode for Symphony in this repo. The upstream docs do not
  recommend it, and local macOS behavior has been more reliable with Symphony attached to a real
  terminal.
- If you intentionally need an unattended overnight run, use a terminal multiplexer such as
  `screen` or `tmux` as an operational fallback, not as the primary documented workflow.
- In this repo, `Human Review` should mean the issue has a real review handoff: pushed branch,
  GitHub PR, commit SHA, and proof-of-work comment in Linear. If those artifacts do not exist, the
  issue is not actually ready for review and should stay in `In Progress` or move to `Rework`.

## Workflow Customization

Edit `Symphony/WORKFLOW.md` if you need to change:

- Linear state mapping (`active_states`, `terminal_states`)
- Workspace hook behavior (`hooks.after_create`)
- Codex runtime options (`codex.*`)
- Agent behavior prompt/body
