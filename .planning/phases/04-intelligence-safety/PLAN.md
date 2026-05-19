# Phase 4 — Intelligence & Safety Features

**Status:** completed  
**Depends on:** Phase 3 ✓  
**Completed tasks:** 24/24

## Goal
Five advanced features that make crisp uniquely powerful among CLI updaters:
orphan tracking, deprecation radar, release notes digest, rollback snapshots, AI toolkit health,
plus an interactive module configuration picker so routine enable/disable changes do not
require manually editing `crisp.conf`.

---

## 4A — Orphan Manager

### T1: Intelligent orphan detection engine
- **Status:** completed
- **Files:** `lib/modules/orphans.sh`
- **Detection pipeline** — Scan ALL PATH directories: `brew --prefix/bin`, `~/.cargo/bin`, `~/.local/bin`, `/usr/local/bin`:
  1. For each binary: `brew list` / `cargo install --list` / `npm list -g` / `pip show` → **package-managed = SKIP**
  2. **Everything else = ORPHAN** → `strings "$binary" | grep -Eo "github\.com/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+"`
  3. Found GitHub repo → **GitHub Releases API ONLY**: `GET /repos/owner/repo/releases/latest`
     - Has releases? → Download platform-matching asset, extract binary, replace old
     - No releases? → **SKIP** (never pull random commits!)
  4. Record in inventory: name, version, repo, detection_method="strings"
- **Key principle:** `strings` buldu + Releases var = tek jenerik update mekanizması. Release yok = dokunma.
- **Install-root discovery** — For every detected tool:
  - resolve command path with `command -v <tool>`
  - follow symlinks to the real binary/script
  - map binary/script back to install root or source repo when possible
  - inspect known metadata: `Makefile`, `install.sh`, package manager metadata, inventory entries
  - inspect CLI help safely: `<tool> --help`, `<tool> help`, `<tool> update --help`, `<tool> self-update --help`
  - detect built-in updater commands such as `hermes update`, `omx update`, `<tool> self-update`, or documented repo update scripts
  - choose a trusted update recipe if available; otherwise mark as detected-but-unsupported
- **Inventory schema** — `~/.local/share/crisp/inventory.json`:
  ```json
  {
    "binaries": {
      "lazygit": {
        "version": "0.44.0",
        "source": "github.com/jesseduffield/lazygit",
        "detection_method": "strings",
        "install_method": "go_install",
        "installed_at": "2026-05-18T15:30:00Z",
        "binary_path": "/opt/homebrew/bin/lazygit"
      }
    }
  }
  ```
- **Verification:** Orphan scan finds `lazygit` (go_install), `fzf` (git clone), `delta` (cargo), `bat` (cargo) correctly

### T2: Version comparison
- **Status:** completed
- **Files:** `lib/modules/orphans.sh`
- GitHub Releases API call: `GET /repos/<owner>/<repo>/releases/latest`
- Parse `tag_name` → semantic version
- Compare local vs remote → `behind` / `current` / `ahead`
- `crisp check-orphans` → table: name, local ver, latest ver, status
- **Verification:** `crisp check-orphans` shows correct comparison for test repos

### T3: Batch update
- **Status:** completed
- **Files:** `lib/modules/orphans.sh`
- `crisp update-orphans` → for each binary with `behind` status
- Show what will be updated, ask confirmation
- Run update using detected install method or trusted recipe:
  - package manager: `brew upgrade`, `pipx upgrade`, `npm update -g`, `cargo install`, etc.
  - built-in CLI updater: e.g. `hermes update`, `omx update`, `<tool> self-update`
  - GitHub Release asset replacement when safe asset matching succeeds
  - repo-local script only when it matches a trusted recipe; never execute arbitrary discovered scripts blindly
- Update inventory with new version + timestamp
- **Verification:** `crisp update-orphans` updates all outdated binaries

### T4: Trusted update recipes
- **Status:** completed
- **Files:** `lib/core/recipes.sh`, `recipes/*.conf`, `lib/modules/orphans.sh`
- Add a curated recipe system for tools whose correct update path is known:
  ```ini
  name=omx
  detect=command -v omx
  help_probe=omx update --help
  update=omx update
  ```
- Initial recipes should cover obvious self-updating tools, including `hermes` and `omx`.
- Recipes must declare detection, update command, safety notes, and optional version check command.
- Discovery can suggest a recipe candidate from help text, but execution requires a trusted recipe or explicit user confirmation.
- **Verification:** `crisp check-orphans` reports recipe-backed update methods for `hermes`/`omx` when installed.

### T5: Uninstall support
- **Status:** completed
- **Files:** `lib/modules/orphans.sh`
- `crisp uninstall <name>` → remove binary + remove from inventory
- `crisp list-orphans` → show all tracked binaries with status
- `crisp orphans --prune` → remove entries for binaries no longer on disk
- **Verification:** `crisp uninstall lazygit` removes binary and inventory entry

---

## 4B — Deprecation Radar

### T6: Abandonment detection engine
- **Status:** completed
- **Files:** `lib/modules/radar.sh`
- For each local tracked repo, resolve its GitHub origin and fetch repo metadata via GitHub API:
  - `pushed_at` → > 12 months → "⚠ No commits in 1 year"
  - `releases` → latest release date, frequency
  - `open_issues` / `closed_issues` → closure rate
- Score: 0-100 (0 = active, 100 = fully abandoned)
- **Verification:** `crisp radar` detects known-abandoned test repos

### T7: Alternative suggestions
- **Status:** completed
- **Files:** `lib/modules/radar.sh`
- For repos flagged as abandoned:
  - GitHub repository search by topic/language/name
  - Filter: same language, active (pushed < 3 months), meaningful community signal
- Display: "⚠ X appears abandoned → Try: Y (active alternative)"
- **Verification:** Radar suggests real alternatives for deprecated repos

### T8: CI/CD rot sub-check
- **Status:** completed
- **Files:** `lib/modules/radar.sh`
- For repos with GitHub Actions: check last workflow run date
- > 6 months since last CI run → "⚠ CI appears inactive"
- Combined with commit inactivity → stronger deprecation signal
- **Verification:** Detects inactive CI on test repos

---

## 4C — Release Notes Digest

### T9: Release notes fetcher
- **Status:** completed
- **Files:** `lib/modules/common.sh` (integrate into `_run_module`)
- Before updating a module, if source is GitHub:
  - Fetch latest release body from `GET /repos/<owner>/<repo>/releases/latest`
  - Parse markdown body → extract first 3-5 bullet points
- **Verification:** Digest appears before module update

### T10: Change classification
- **Status:** completed
- **Files:** `lib/modules/common.sh`
- Classify each bullet point:
  - `🔒 Security:` — keywords: CVE, security, vulnerability, patch
  - `⚠ Breaking:` — keywords: breaking, deprecated, removed, migration
  - `✨ Feature:` — keywords: feat, add, new, support
  - `🐛 Fix:` — keywords: fix, bug, crash, issue
- **Verification:** Classification works on real GitHub release notes

### T11: Digest display
- **Status:** completed
- **Files:** `lib/modules/common.sh`
- Format:
  ```
  ⬆ lazygit v0.42 → v0.44
     ✨ Feature: Custom pagers support (#4123)
     🐛 Fix: crash on large repos (#4098)
     🔒 Security: GHSA-xxxx buffer overflow (medium)
  ```
- Show during `crisp all`, `crisp <module>`, `crisp update-orphans`
- **Verification:** Digest shows correctly for real module updates

---

## 4D — Rollback Snapshots

### T12: Pre-update backup
- **Status:** completed
- **Files:** `lib/modules/rollback.sh`
- Before binary update: `cp <binary> ~/.local/share/crisp/backups/<name>/<version>/<binary>`
- Write `metadata.json` alongside: version, date, source, checksum
- **Verification:** Backup created before orphan update

### T13: Rollback command
- **Status:** completed
- **Files:** `lib/modules/rollback.sh`
- `crisp rollback --list` → show all backups with versions and dates
- `crisp rollback <name>` → restore latest backup of that binary
- `crisp rollback <name> <version>` → restore specific version
- `cp <backup> <original_path>` + chmod
- **Verification:** `crisp rollback lazygit v0.42` restores v0.42 binary

### T14: Backup cleanup
- **Status:** completed
- **Files:** `lib/modules/rollback.sh`
- `crisp clean-backups` → remove backups older than 30 days
- `crisp clean-backups --all` → remove all backups (confirm)
- Config: `CRISP_BACKUP_RETENTION_DAYS` in `crisp.conf` (default 30)
- **Verification:** Old backups removed, recent ones kept

### T15: Safety checks
- **Status:** completed
- **Files:** `lib/modules/rollback.sh`
- Before rollback: verify backup file exists, checksum matches
- After rollback: verify binary is executable
- Show diff: "v0.44 → v0.42 (downgrade 2 versions)"
- **Verification:** Checksum mismatch → error, no restore

---

## 4E — AI Toolkit Health

### T16: ML tool detection
- **Status:** completed
- **Files:** `lib/modules/ai-health.sh`
- Detect installed ML tools:
  - `pip list | grep -E "torch|transformers|vllm|ollama"`
  - `brew list | grep -E "ollama|llama.cpp"`
  - Binary check: `which ollama vllm llama.cpp`
- Record versions in structured format
- **Verification:** Detects all installed ML tools

### T17: GPU/CUDA compatibility check
- **Status:** completed
- **Files:** `lib/modules/ai-health.sh`
- macOS: `system_profiler SPDisplaysDataType` → GPU model
- Linux: `nvidia-smi` → driver version, CUDA version
- Check PyTorch CUDA compatibility: `python3 -c "import torch; print(torch.version.cuda)"`
- Report mismatches: "⚠ CUDA 12.4 requires PyTorch >= 2.2.0, you have 2.1.0"
- **Verification:** Correct compatibility report on GPU machine

### T18: Release notifications
- **Status:** completed
- **Files:** `lib/modules/ai-health.sh`
- Check PyPI for latest versions of tracked ML packages
- Compare with installed versions
- Show relevant features from release notes
- `crisp ai-health` → full report with recommendations
- **Verification:** Detects outdated ML packages

### T19: Health report format
- **Status:** completed
- **Files:** `lib/modules/ai-health.sh`
- Clean terminal output:
  ```
  🤖 AI Toolkit Health Report
  ─────────────────────────────
  ✅ PyTorch 2.5.1 (CUDA 12.4 compatible)
  ⚠ transformers 4.45.0 → 4.48.0 (adds Gemma 3)
  ✅ Ollama 0.5.7 (latest)
  ⚠ vLLM not installed
  ─────────────────────────────
  GPU: Apple M4 Pro (no CUDA)
  ```
- **Verification:** Report renders cleanly on macOS and Linux

### T20: Menu integration
- **Status:** completed
- **Files:** `crisp` (main menu)
- Add menu items for new commands:
  - "Orphan Manager" → `crisp update-orphans` sub-menu
  - "Deprecation Radar" → `crisp radar`
  - "Rollback Manager" → `crisp rollback --list`
  - "AI Health Check" → `crisp ai-health`
- Keep existing items + add new ones
- **Verification:** All menu items navigate correctly

---

## 4F — Interactive Module Configuration

### T21: Config picker UI
- **Status:** completed
- **Files:** `crisp`, `lib/core/ui.sh`
- Replace the current read-only `crisp config` screen with an interactive picker:
  - ↑/↓ or j/k moves through available modules
  - Space toggles selected module on/off
  - Enter saves selected modules
  - q/Esc cancels without writing
- Show active/inactive state inline with checkmarks and a concise help footer.
- Keep redraw height within terminal bounds; fall back to compact rows on small terminals.
- **Verification:** User can toggle modules without opening `~/.config/crisp/crisp.conf`; no row duplication while navigating.

### T22: Config persistence writer
- **Status:** completed
- **Files:** `crisp`, `lib/core/common.sh`
- Write selected modules back to `~/.config/crisp/crisp.conf` as `CRISP_MODULES="..."`.
- Use atomic write (`tmp` file then `mv`) and create a timestamped backup before overwriting.
- Preserve existing comments/settings where practical; only replace or append the `CRISP_MODULES` line.
- Validate at least one module remains enabled and every saved module exists in `lib/modules/`.
- **Verification:** Save updates `CRISP_MODULES`, backup exists, invalid/empty selections are rejected safely.

### T23: Config picker tests
- **Status:** completed
- **Files:** `tests/test_config_picker.bats`
- Cover toggle state, save/cancel paths, config writer, missing module handling, and short-terminal compact rendering.
- **Verification:** `bats tests/test_config_picker.bats` passes.

### T24: Config UX documentation
- **Status:** completed
- **Files:** `README.md`, `crisp.conf`
- Document interactive module selection and manual config fallback.
- Include keybindings: ↑/↓, j/k, Space, Enter, q/Esc.
- **Verification:** README explains both UI and direct config-file workflows.

## Verification Summary
- [ ] T1-T5: Orphan manager tracks, discovers install roots, uses trusted recipes, compares, updates, uninstalls
- [ ] T6-T8: Radar detects abandoned repos + suggests alternatives
- [ ] T9-T11: Release notes digest shown before updates
- [ ] T12-T15: Rollback snapshots save and restore correctly
- [ ] T16-T19: AI health check reports accurately
- [ ] T20: Menu integration complete
- [ ] T21-T24: Interactive config picker toggles modules, saves safely, and is documented

## Files
- **New:** `lib/modules/orphans.sh`, `lib/modules/radar.sh`, `lib/modules/rollback.sh`, `lib/modules/ai-health.sh`, `lib/core/recipes.sh`, `recipes/*.conf`
- **New:** `~/.local/share/crisp/inventory.json`, `~/.local/share/crisp/backups/`
- **New:** `tests/test_config_picker.bats`
- **Modified:** `crisp` (menu items, new subcommands, interactive `config` picker), `lib/core/common.sh` (release digest integration + config writer), `lib/core/ui.sh`, `README.md`, `crisp.conf`
