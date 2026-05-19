# crisp v2.0 — ROADMAP

## Phase 1: Fix TUI & Core Stability ✅
**Status:** Complete (2026-05-18) · **13/13 tasks** · [Summary](phases/01-fix-tui-core/SUMMARY.md)

### Key Deliverables
- [x] **Fix TUI rendering** — No item stacking/duplication; clean redraw on every keypress
- [x] **Stable read_key()** — Arrow keys, Enter, q/v/h/j/k/1-9 all work 100%
- [x] **Clean exit handling** — Ctrl+C graceful exit, no terminal corruption
- [x] **Auto-dismiss dialogs** — "Press any key" prompts timeout after 5s auto-return
- [x] **Modular UI functions** — Extract `_draw_header`, `_draw_menu`, `_draw_footer`
- [x] **Terminal compatibility** — Terminal.app, iTerm2, VS Code, GNOME, Windows Terminal
- [x] **Bash 5.x requirement** — Enforce via shebang + version check
- [x] **Cross-platform shebang & paths** — `#!/usr/bin/env bash`, XDG-compliant base paths
- [x] **OS detection** — `detect_os()` in base.sh returns macos/linux/windows
- [x] **`--dry-run` mode** — Preview what would be updated without making changes
- [ ] **Parallel module execution** — Run independent modules (brew/pip/npm) simultaneously for speed (deferred to Phase 4)

### Approach (from Mole)
- Mole uses simple `clear_screen` + full redraw on every keypress — reliable
- `read_key()` with `read -t 1` for escape sequences (bash 5.x compatible)
- Vim-like keybindings (j/k, q, h, v, numbers)

### Files Changed
- `crisp` — major refactor of TUI functions
- New: `lib/core/ui.sh` — extracted UI functions

---

## Phase 2: File Structure & Project Infrastructure ✅
**Status:** Complete (2026-05-19) · **18/18 tasks** · [Summary](phases/02-structure-infra/SUMMARY.md)

### 2A — Directory Restructure
- [x] **New directory tree**:
  ```
  crisp/
  ├── crisp                    # Main CLI (thin orchestrator, ~200 lines)
  ├── lib/
  │   ├── core/
  │   │   ├── base.sh          # Colors, icons, constants, OS detection, traps
  │   │   ├── ui.sh            # read_key, draw_menu, spinners, helpers
  │   │   └── common.sh        # Module runner, _run_module, helpers
  │   └── modules/
  │       ├── brew.sh          # (moved from old modules/)
  │       ├── pip.sh
  │       ├── pipx.sh
  │       ├── npm.sh
  │       ├── npx.sh
  │       ├── uv.sh
  │       ├── cargo.sh
  │       ├── code.sh          # VS Code + Cursor + Windsurf + VSCodium
  │       ├── editors.sh       # All editor extensions (Zed, Neovim, Antigravity)
  │       ├── hermes.sh
  │       ├── repos.sh
  │       ├── graphify.sh
  │       ├── gem.sh           # Ruby gems
  │       ├── composer.sh      # PHP Composer global
  │       ├── mas.sh           # Mac App Store (macOS)
  │       ├── snap.sh          # Snap packages (Linux)
  │       ├── flatpak.sh       # Flatpak (Linux)
  │       └── brew-cask.sh     # Homebrew cask GUI apps
  ├── tests/
  │   ├── test_ui.bats
  │   ├── test_modules.bats
  │   └── test_cron.bats
  ├── scripts/
  │   └── (empty — Phase 4 adds orphan/radar scripts)
  ├── completions/
  │   ├── crisp.bash
  │   ├── crisp.zsh
  │   ├── crisp.fish
  │   └── crisp.ps1            # PowerShell
  ├── crisp.conf
  └── README.md
  ```
- [x] **Guard-based sourcing** — `CRISP_*_LOADED` pattern (like Mole's `MOLE_*_LOADED`)
- [x] **Cross-platform module loading** — `brew.sh` only on macOS; `apt.sh` for Linux; common modules everywhere
- [x] **XDG-compliant paths** — Config: `$XDG_CONFIG_HOME/crisp/`, Data: `$XDG_DATA_HOME/crisp/`
- [ ] **Smart repos management** — Whitelist-first, subsequent auto: (deferred to Phase 4)
  - **First run**: `crisp repos --discover` → scans all local repos → checkbox picker → saves to `~/.config/crisp/repos.conf`
  - **Normal run**: `crisp repos` → only pulls tracked repos, auto-skips dirty/ahead/detached
  - **New repo detection**: "⚡ ~/new-clone found — track it? (y/n/skip-all)"
  - **Re-pick**: `crisp repos --select` → re-open picker to add/remove
  - Auto-skip: dirty working tree, unpushed commits, detached HEAD
  - Config: `track: ~/path` (checked = update) + `skip: ~/path` (unchecked = blacklist, never ask again)

### 2B — Project Infrastructure
- [x] **`.editorconfig`** — indent_style=space, indent_size=2, charset=utf-8, trim_trailing_whitespace
- [x] **`LICENSE`** — MIT License
- [x] **`.shellcheckrc`** — ShellCheck config: enable=all, disable=SC2034
- [x] **`crisp.conf` template** — Default config with all modules + comments
- [ ] **`repos.conf` template** — Repo blacklist: `skip: ~/work/private-project` (deferred)
- [x] **`CONTRIBUTING.md`** — How to add modules, run tests, submit PRs
- [x] **`SECURITY.md`** — Basic security policy + reporting
- [x] **Pre-commit hooks** — `.githooks/pre-commit`:
  - `shellcheck lib/**/*.sh crisp` (block commit on errors)
  - `shfmt -d -i 2 -ci` (check formatting)
  - `bats tests/` (run tests)
- [x] **`.github/dependabot.yml`** — Auto-update GitHub Actions versions
- [ ] **`CONTRIBUTORS.svg`** — Auto-generated via GitHub Action (low priority, add CI step)

### 2C — Testing
- [x] **Bats test suite** — install bats-core, write tests:
  - `test_ui.bats` — key handling (arrow, enter, quit, numbers)
  - `test_modules.bats` — module loading, error isolation, cross-platform skip
  - `test_cron.bats` — cron expression generation for all presets
 - [x] **ShellCheck compliance** — All `.sh` files pass `shellcheck` with zero errors (CI enforcement pending)
- [x] **README rewrite** — Usage, install, config, contributing (macOS + Linux + Windows)

### Files Changed
- Major restructure — all files reorganized
- New: `lib/core/*.sh`, `tests/*.bats`, `.editorconfig`, `.shellcheckrc`, `LICENSE`,
  `CONTRIBUTING.md`, `SECURITY.md`, `.githooks/pre-commit`

---

## Phase 3: CI/CD & Distribution ✅
**Status:** Complete (2026-05-19) · **14/14 tasks** · [Summary](phases/03-cicd-distribution/SUMMARY.md)
**Goal**: GitHub Actions CI, Makefile, install.sh, Homebrew formula, self-update — ship it.

### 3A — CI/CD Pipeline
- [x] **`.github/workflows/ci.yml`**:
  - Matrix: `ubuntu-latest` + `macos-latest`
  - Steps: checkout → install bats → shellcheck → bats tests
  - ShellCheck: `shellcheck lib/**/*.sh crisp`
  - Fail on any warning
- [x] **`.github/workflows/release.yml`**:
  - Trigger: git tag `v*`
  - Build: no build needed (pure bash)
  - Create GitHub Release with changelog
  - Update Homebrew formula with new version + SHA

### 3B — Build & Install
 - [x] **`Makefile`** — OS-aware:
  - `make install` → detect OS, symlink to correct binary path
  - `make install-completions` → bash/zsh/fish/pwsh
  - `make test` → `bats tests/`
  - `make lint` → `shellcheck lib/**/*.sh crisp`
  - `make uninstall` → remove symlinks + config (asks confirmation)
  - `make clean` → remove temp/cache files
 - [x] **`install.sh`** — One-liner cross-platform installer:
  - OS detection (macOS/Linux/Windows-WSL)
  - Bash 5.x check
  - Clone/download to `$CRISP_HOME`
  - Symlink binary to PATH
  - Install completions
  - `curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash`

### 3C — Distribution
 - [x] **macOS: Homebrew formula** — `enesdemir/homebrew-tap/crisp`
  - Formula at `homebrew-tap/Formula/crisp.rb`
  - Auto-updated by release workflow
 - [x] **Shell completions** — Generate + ship with install:
  - Bash: `complete -W "all quick repos cron list help" crisp`
  ...
  - Fish: `complete -c crisp -f -a "all quick repos cron list help"`
  - PowerShell: `Register-ArgumentCompleter`
 - [x] **Self-update** — `crisp update` (OS-aware):
  - macOS: `brew upgrade enesdemir/tap/crisp`
  - Linux/WSL: `git -C $CRISP_HOME pull` or `curl install.sh | bash`
 - [x] **PATH setup** — `crisp setup-path`:
  - Detect `$SHELL` → write export to correct rc file
  - bash → `~/.bashrc`, zsh → `~/.zshrc`, fish → `~/.config/fish/config.fish`
 - [x] **Version management** — Git tags `v1.0.0` → `CRISP_VERSION` detection

### Files Changed
- New: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `Makefile`,
  `install.sh`, `Formula/crisp.rb`, `completions/*`
- Update: `crisp` (add `update` and `setup-path` commands)

---

## Phase 4: Intelligence & Safety Features ✅
**Status:** Complete (2026-05-19) · **24/24 tasks** · [Summary](phases/04-intelligence-safety/SUMMARY.md)
**Goal**: Five advanced features that make crisp uniquely powerful — orphan tracking, 
deprecation radar (local repos), release notes, rollback snapshots, AI toolkit health,
and a usable interactive configuration picker.
### 4A — Orphan Manager (`crisp update-orphans`)
- [x] **Inventory system** — Track every binary in `~/.local/share/crisp/inventory.json`
- [x] **Install-root discovery** — `command -v`, symlink resolution, binary → install root/repo mapping, and safe metadata/help probes
- [x] **Trusted update recipes** — detect package-manager updaters and CLI self-updaters such as `hermes update`, `omx update`, or `<tool> self-update`
- [x] **Version comparison** — GitHub Releases API vs local binary version
- [x] **Batch update** — `crisp update-orphans` updates all tracked binaries
- [x] **Install/Remove** — `crisp uninstall <name>` removes crisp-installed bin
- [x] **Module**: `lib/modules/orphans.sh`

### 4B — Deprecation Radar (`crisp radar`) ⭐
- [x] **Abandonment signals**: pushed_at > 1yr, release gaps, issue closure rate
- [x] **Alternative suggestions** — GitHub repo metadata/search for active alternatives to local tracked repos
- [x] **CI/CD rot detection** — Last CI run > 6 months
- [x] **Module**: `lib/modules/radar.sh`

### 4C — Release Notes Digest (integrated into update flow)
- [x] **Pre-update summary** — GitHub Releases body → classify: breaking/security/feature/fix
- [x] **Integration** — `_run_module()` and `update-orphans` show digest before updating

### 4D — Rollback Snapshots
- [x] **Pre-update backup** → `~/.local/share/crisp/backups/<name>/<version>/`
- [x] **Rollback** → `crisp rollback <name>` restores previous version
- [x] **Auto-cleanup** → 30-day retention
- [x] **Module**: `lib/modules/rollback.sh`

### 4E — AI Toolkit Health
- [x] **ML tool versions** — Ollama, vLLM, llama.cpp, transformers, PyTorch
- [x] **GPU/CUDA compatibility** — driver ↔ CUDA ↔ framework matrix
- [x] **Smart notifications** — New releases with relevant features
- [x] **Module**: `lib/modules/ai-health.sh`

### 4F — Interactive Module Configuration
- [x] **Replace read-only config screen** — `crisp config` becomes a navigable module picker instead of only printing `crisp.conf`
- [x] **Keyboard UX** — ↑/↓ or j/k to move, Space to toggle a module, Enter to save, q/Esc to cancel
- [x] **Two-pane/status UI** — show active modules, all available modules, and changed state clearly without overflowing the terminal
- [x] **Safe persistence** — write selected modules back to `~/.config/crisp/crisp.conf` atomically, preserve comments where practical, and create a backup before overwrite
- [x] **Validation** — require at least one active module, skip missing module files, and show a clear error if config is not writable
- [x] **Tests** — cover toggle behavior, save/cancel paths, config writer, and terminal height fallback

### Files Changed (Phase 4)
- New: `lib/modules/orphans.sh`, `radar.sh`, `rollback.sh`, `ai-health.sh`
- New: `~/.local/share/crisp/inventory.json`, `~/.local/share/crisp/backups/`
- Update: `crisp` (menu items, new subcommands, interactive `config` picker)
