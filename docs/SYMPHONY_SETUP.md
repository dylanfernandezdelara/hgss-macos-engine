# Symphony Setup

This repository includes a Symphony workflow template and helper launcher.

## What Was Added

- `Symphony/WORKFLOW.md`: Symphony workflow config + agent prompt for this repo.
- `scripts/run_symphony.sh`: bootstraps the upstream `openai/symphony` Elixir reference implementation and launches it with this repo's workflow.

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

```bash
./scripts/run_symphony.sh
```

The launcher automatically adds Symphony's required preview acknowledgment flag.

With dashboard port enabled:

```bash
./scripts/run_symphony.sh --port 4000
```

## Workflow Customization

Edit `Symphony/WORKFLOW.md` if you need to change:

- Linear state mapping (`active_states`, `terminal_states`)
- Workspace hook behavior (`hooks.after_create`)
- Codex runtime options (`codex.*`)
- Agent behavior prompt/body
