# crisp

**Keep everything up to date, in one command.**

A cross-platform CLI tool that updates all your dev tools — package managers,
AI agent skills, VS Code extensions, local repos, and more — with a single
interactive TUI or a quick CLI command.

## Quick Start

```bash
# macOS (Homebrew)
brew install enesdemir/tap/crisp

# Linux / WSL
curl -fsSL https://raw.githubusercontent.com/EnesDemir143/crisp/main/install.sh | bash
```

**Requirements:** Bash 5.0+ (`brew install bash` on macOS)

## Usage

```bash
crisp                  # interactive TUI menu
crisp all              # run all enabled modules
crisp quick            # quick update (brew/apt/pip/npm/uv)
crisp <module>         # run a specific module
crisp cron             # schedule auto-update
crisp config           # interactive module picker
crisp list             # list available modules
crisp --dry-run        # preview without changes
```

### Orphan Manager

| Command | Description |
|---------|-------------|
| `crisp scan-orphans`   | Detect standalone binaries not managed by package managers |
| `crisp check-orphans`  | Compare orphan versions against latest GitHub releases      |
| `crisp update-orphans` | Batch-update all out-of-date orphans                        |
| `crisp list-orphans`   | List all tracked orphan binaries                            |
| `crisp uninstall <n>`  | Remove a binary from orphan tracking                        |

From the interactive menu, `Orphan Manager` opens a submenu where you can select
actions by number (1-6).

### Rollback Manager

| Command | Description |
|---------|-------------|
| `crisp rollback --list` | List all available binary backups           |
| `crisp rollback <name>` | Restore latest backup of a binary           |
| `crisp clean-backups`   | Remove backups older than 30 days            |

### Config Picker

`crisp config` opens an interactive module toggle screen. OS-incompatible
modules (e.g. `apt` on macOS, `brew` on Linux) are automatically hidden.

| Key | Action |
|-----|--------|
| `↑/↓` | Navigate |
| `Space` | Toggle module on/off |
| `Enter` | Save and exit |
| `q` / `Esc` | Cancel |

### Keyboard Shortcuts (Main Menu)

| Key | Action |
|-----|--------|
| `↑/↓` or `j/k` | Navigate |
| `Enter` | Select |
| `1-9` | Quick select by number |
| `g` | Jump to top |
| `v` | Version info |
| `h` | Help |
| `q` | Quit |

## Modules

| Module | Description | OS |
|--------|-------------|----|
| `brew` | brew update + brew upgrade | macOS |
| `apt` | apt update && apt upgrade | Linux |
| `pip` | pip self-upgrade + outdated packages | All |
| `pipx` | pipx upgrade-all | All |
| `npm` | npm self-update + global packages | All |
| `npx` | Clear npx cache | All |
| `uv` | uv self update + uv tool upgrade --all | All |
| `cargo` | cargo install-update -a | All |
| `hermes` | Hermes Agent update | All |
| `graphify` | graphify version check & update | All |
| `code` | VS Code extensions update | All |
| `repos` | Fast-forward pull tracked local repos | All |
| `orphans` | Orphan binary detection & update | All |
| `radar` | Deprecation radar for local repos | All |
| `rollback` | Backup & restore binary versions | All |
| `ai-health` | AI toolkit health check (ML tools, GPU) | All |

## Configuration

`~/.config/crisp/crisp.conf`:

```bash
CRISP_MODULES="graphify brew pip pipx npm npx uv hermes repos code cargo"
```

## Project Structure

```
crisp/
├── crisp                    # Main CLI
├── lib/
│   ├── core/
│   │   ├── base.sh          # OS detection, colors, icons, XDG paths
│   │   ├── ui.sh            # Terminal control, read_key, draw primitives
│   │   ├── common.sh        # Module runner, discovery, release notes
│   │   └── recipes.sh       # Trusted update recipes
│   └── modules/             # 16 update modules
│       ├── brew.sh apt.sh pip.sh pipx.sh npm.sh npx.sh
│       ├── uv.sh cargo.sh code.sh hermes.sh graphify.sh
│       ├── repos.sh orphans.sh radar.sh rollback.sh
│       └── ai-health.sh
├── tests/                   # 61 Bats tests
├── completions/             # bash/zsh/fish/powershell
├── Formula/                 # Homebrew formula
└── install.sh               # One-liner installer
```

## Development

```bash
make test          # Run Bats tests (61 tests)
make lint          # ShellCheck all .sh files
```

## License

[MIT](LICENSE) — Enes Demir
