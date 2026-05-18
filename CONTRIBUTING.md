# Contributing to crisp

Thank you for your interest in contributing!

## Quick Start

```bash
git clone https://github.com/EnesDemir143/crisp.git
cd crisp
make install-hooks  # Install pre-commit hooks
```

## Adding a New Module

1. Create `lib/modules/yourmodule.sh`:
   ```bash
   #!/usr/bin/env bash
   # crisp module: yourmodule
   # Description of what it does

   [[ -n "${CRISP_MOD_YOURMODULE_LOADED:-}" ]] && return 0
   readonly CRISP_MOD_YOURMODULE_LOADED=1

   # Optional: platform gating
   # [[ "${CRISP_OS:-unknown}" != "macos" ]] && return 0

   crisp_yourmodule_run() {
     echo "  → Running yourmodule..."
     # Your update logic here
     echo "    ✓ yourmodule done"
   }
   ```

2. Add the module name to your `crisp.conf`:
   ```
   CRISP_MODULES="graphify brew pip npm yourmodule"
   ```

3. Add a description in `lib/core/common.sh` → `_module_desc()`.

## Code Style

- **2-space indent** (spaces, not tabs)
- **English only** for user-facing output
- **Bash 5.0+** — use `[[ ]]` not `[ ]`, `read -t 0.5` for timeouts
- **Guard pattern** — every sourced file needs a `CRISP_*_LOADED` guard
- **Error isolation** — one module fails, others continue

## Running Tests

```bash
make test          # Run all Bats tests
make lint          # Run ShellCheck on all .sh files
bats tests/test_ui.bats  # Run specific test file
```

## Pre-Commit Hooks

```bash
make install-hooks   # Install hooks
make uninstall-hooks # Remove hooks
```

Hooks run: ShellCheck + shfmt + bats automatically.

## Pull Request Process

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes
4. Run `make lint && make test`
5. Commit with a clear message
6. Open a PR

## Security

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.
