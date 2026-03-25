# Luke Agents

Personal remix of [Craft Agents](https://github.com/lukilabs/craft-agents-oss) with custom features. Runs alongside the official app with a separate bundle ID and data directory.

| | Craft Agents (official) | Luke Agents (this branch) |
|---|---|---|
| App name | Craft Agents | Luke Agents |
| Bundle ID | `com.lukilabs.craft-agent` | `com.lukeybeachboy.luke-agents` |
| Data dir | `~/.craft-agent/` | `~/.craft-agent/` (shared!) |
| Electron dir | `~/Library/Application Support/Craft Agents/` | `~/Library/Application Support/Luke Agents/` |
| Source | Official releases | Built from `luke/dev` branch |

Both apps share the same data directory — your sources, skills, workspaces, preferences, and conversations are available in both. They can run simultaneously because Electron's internal state (singleton lock, caches) is separate.

## Custom Features

- **Copilot premium request usage indicator** — shows percentage used next to model name, same data as VS Code ([PR #473](https://github.com/lukilabs/craft-agents-oss/pull/473))

## Prerequisites

- [Bun](https://bun.sh/) installed
- macOS with Xcode Command Line Tools

## Setup

```bash
# Clone from your fork
git clone https://github.com/LukeyBeachBoy/craft-agents-oss.git
cd craft-agents-oss
git checkout luke/dev

# Add the official repo as upstream (for pulling updates)
git remote add upstream https://github.com/lukilabs/craft-agents-oss.git

# Install dependencies
bun install
```

## Development (live reload)

For active development with hot-reload on the renderer (UI changes update instantly):

```bash
# 1. Build the main process (required after changing main process files)
cd apps/electron
bun run build:main

# 2. Start the dev server (hot-reloads renderer/UI changes)
bun run dev

# 3. In another terminal, start Electron pointing at the dev server
bun run electron:dev
```

**What hot-reloads and what doesn't:**

| Change | Hot-reloads? | What to do |
|--------|-------------|------------|
| Renderer / UI (`src/renderer/`) | ✅ Yes | Just save the file |
| Main process (`src/main/`) | ❌ No | Run `bun run build:main` then restart the app |
| Shared packages (`packages/`) | ❌ No | Run `bun run build:main` then restart the app |
| Preload scripts (`src/preload/`) | ❌ No | Run `bun run build:preload` then restart the app |

## Building the full app

To build a packaged `Luke Agents.app` that installs alongside the official Craft Agents:

```bash
cd apps/electron
./build-luke.sh
```

This outputs `release/Luke-Agents-arm64.dmg`. Open it and drag to Applications.

**After installing**, remove macOS quarantine (required since the app isn't notarized):

```bash
xattr -cr /Applications/Luke\ Agents.app
```

## Branch Strategy

```
main                    ← always mirrors official repo, never commit here
  │
  ├── feat/copilot-usage    ← one branch per feature (used for PRs)
  ├── feat/dark-theme       ← another feature
  │
  └── luke/dev              ← YOUR daily driver, merges all features together
```

### Pulling official updates

When the Craft Agents team releases updates:

```bash
# 1. Update main from the official repo
git checkout main
git pull upstream main

# 2. Rebase your combo branch onto the new main
git checkout luke/dev
git rebase main

# If there are conflicts, resolve them, then:
# git add <resolved files>
# git rebase --continue

# 3. Force-push to your fork (since rebase rewrites history)
git push fork luke/dev --force-with-lease
```

### Adding a new custom feature

```bash
# 1. Create a feature branch from main (keeps it clean for a PR)
git checkout main
git pull upstream main
git checkout -b feat/my-new-thing

# 2. Make your changes, commit them
git add .
git commit -m "feat: my new thing"

# 3. Push to your fork and create a PR (optional, if you want to contribute upstream)
git push fork feat/my-new-thing
gh pr create --repo lukilabs/craft-agents-oss --head LukeyBeachBoy:feat/my-new-thing

# 4. Merge into your combo branch so you can use it day-to-day
git checkout luke/dev
git merge feat/my-new-thing

# 5. Rebuild
cd apps/electron
./build-luke.sh
```

### If a PR gets merged into official

Once the Craft Agents team merges your PR, the feature is now in `main`. Next time you pull updates, it'll be included automatically. You can delete the feature branch:

```bash
git branch -d feat/my-merged-thing
```

## Copilot Usage Indicator Setup

The premium request indicator requires a GitHub fine-grained PAT with **Plan (read)** permission.

1. Create a token at https://github.com/settings/personal-access-tokens/new
   - Token name: anything (e.g. "Luke Agents")
   - Expiration: your preference
   - Account permissions → **Plan**: Read-only
2. Save it:

```bash
echo '{"pat": "github_pat_..."}' > ~/.craft-agent/github-billing.json
chmod 600 ~/.craft-agent/github-billing.json
```
