# crisp

**Keep everything crisp and up-to-date.**

A cross-platform CLI tool that updates all your dev tools in one command.
Beyond brew/pip/npm — crisp can also update local Git repositories, AI agent
skills, and CLI extensions in one go. Think of it as a universal package manager
for the modern AI-augmented dev workflow.

## Quick Start

```bash
# macOS (Homebrew)
brew install enesdemir/tap/crisp

# Linux / WSL (one-liner)
curl -fsSL https://raw.githubusercontent.com/EnesDemir143/crisp/main/install.sh | bash

# Manual
git clone https://github.com/EnesDemir143/crisp.git
ln -s $(pwd)/crisp/crisp /usr/local/bin/crisp
```

**Requirements:** Bash 5.0+ (`brew install bash` on macOS)

## Usage

```bash
crisp                  # interactive TUI menu
crisp all              # run all enabled modules
crisp quick            # quick update (brew/pip/npm)
crisp <module>         # run a specific module
crisp cron             # schedule auto-update
crisp list             # list available modules
crisp --dry-run        # preview without changes
crisp --help           # show help
```

### Orphan Manager

| Command | Description |
|---------|-------------|
| `crisp scan-orphans`   | Detect standalone binaries not managed by package managers |
| `crisp check-orphans`  | Compare orphan versions against latest GitHub releases      |
| `crisp update-orphans` | Batch-update all out-of-date orphans                        |
| `crisp list-orphans`   | List all tracked orphan binaries                            |
| `crisp uninstall <n>`  | Remove a binary from orphan tracking                        |

### Deprecation Radar

| Command | Description |
|---------|-------------|
| `crisp radar` | Scan tracked repos for abandonment signals and suggest alternatives |

### Rollback Manager

| Command | Description |
|---------|-------------|
| `crisp rollback --list` | List all available binary backups           |
| `crisp rollback <name>` | Restore latest backup of a binary           |
| `crisp clean-backups`   | Remove backups older than 30 days (default) |

### AI Health Check

| Command | Description |
|---------|-------------|
| `crisp ai-health` | AI toolkit health report (ML tools, GPU/CUDA compatibility) |

### Interactive Config Picker

| Command | Description |
|---------|-------------|
| `crisp config` | Interactive module picker (Space=toggle, Enter=save, q=cancel) |

**Keybindings:**
| Key | Action |
|-----|--------|
| `↑/↓` or `j/k` | Navigate modules |
| `Space` | Toggle module on/off |
| `Enter` | Save changes |
| `q` or `Esc` | Cancel without saving |

### Keyboard Shortcuts (Interactive Menu)

| Key | Action |
|-----|--------|
| `↑/↓` or `j/k` | Navigate menu |
| `Enter` | Select item |
| `1-9` | Quick select by number |
| `g` | Jump to top |
| `v` | Version screen |
| `h` | Help screen |
| `q` | Quit |

## Modules

| Module | What it does | Platform |
|--------|-------------|----------|
| `brew` | `brew update + brew upgrade` | macOS |
| `apt` | `apt update && apt upgrade` | Linux |
| `pip` | pip self-upgrade + outdated packages | All |
| `pipx` | `pipx upgrade-all` | All |
| `npm` | npm self-update + global packages | All |
| `npx` | Clear npx cache | All |
| `uv` | `uv self update + uv tool upgrade --all` | All |
| `cargo` | `cargo install-update -a` | All |
| `hermes` | Hermes Agent update | All |
| `code` | VS Code extensions update | All |
| `repos` | Fast-forward pull local tracked repos | All |
| `graphify` | graphify version check | All |

## Configuration

crisp reads `~/.config/crisp/crisp.conf`:

```bash
# List of modules to run (space-separated)
CRISP_MODULES="graphify brew pip npm hermes repos"
```

## Project Structure

```
crisp/
├── crisp                    # Main CLI (thin orchestrator)
├── lib/
│   ├── core/
│   │   ├── base.sh          # Colors, icons, OS detection, XDG paths
│   │   ├── ui.sh            # read_key, draw_menu, spinners, format helpers
│   │   └── common.sh        # Module runner, error isolation
│   └── modules/
│       ├── brew.sh          # macOS Homebrew
│       ├── apt.sh           # Linux apt
│       ├── pip.sh           # Python pip
│       └── ...              # 12 modules total
├── tests/
│   ├── test_ui.bats         # Key handling tests
│   ├── test_modules.bats    # Module loading tests
│   └── test_cron.bats       # Cron expression tests
├── .editorconfig
├── .shellcheckrc
├── LICENSE                  # MIT
├── CONTRIBUTING.md
└── SECURITY.md
```

## Development

```bash
make test          # Run Bats tests (47 tests)
make lint          # ShellCheck all .sh files
make install-hooks # Install pre-commit hooks (shellcheck + shfmt + bats)
```

## Roadmap

- **Phase 1** ✅ — TUI fix, full-redraw, vim keybindings, bash 5.0+
- **Phase 2** ✅ — Modular architecture, 12 modules, Bats tests, infrastructure
- **Phase 3** — CI/CD pipeline, Makefile, install.sh, Homebrew formula
- **Phase 4** 🚧 — Orphan manager, deprecation radar, rollback, AI health, config picker

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add modules, run tests, and submit PRs.

## License

[MIT](LICENSE) — Enes Demir
