# Changelog

## 1.0.0 (2026-05-19)


### Features

* add self-update, PATH setup, and git-tag version detection ([aa9de70](https://github.com/EnesDemir143/crisp/commit/aa9de70f1fa0246caa5fa37e59d2910b032c2a4e))
* auxiliary modules — VS Code extensions and graphify ([009e7ca](https://github.com/EnesDemir143/crisp/commit/009e7cafac2eb9fb9e06f8f0dfacde6377a9584a))
* **ci:** add GitHub Actions CI/CD, OS-aware Makefile ([d1a6756](https://github.com/EnesDemir143/crisp/commit/d1a6756b4b061316575dac37595e06746e296ee6))
* core TUI menu engine with module system, cron scheduling, and interactive menu ([4fa8693](https://github.com/EnesDemir143/crisp/commit/4fa869368d25806f9f0d6a69d67dd480de6c6cb5))
* **core:** add TUI foundation — base.sh + ui.sh ([c4a9ea6](https://github.com/EnesDemir143/crisp/commit/c4a9ea6809908374122e8ef618392f2a23b8a417))
* deep star scan with README install detection ([9e37f26](https://github.com/EnesDemir143/crisp/commit/9e37f26abfa3b04192f78760a9210f3d82c38191))
* **dist:** add cross-platform installer, Homebrew formula, shell completions ([48a2683](https://github.com/EnesDemir143/crisp/commit/48a2683bf6c38261e752b56c545eb211f882673c))
* GitHub starred repos integration ([f0978fb](https://github.com/EnesDemir143/crisp/commit/f0978fbf4d6e87e72487828bfb566422b94a375e))
* Intelligence & Safety — orphan manager, deprecation radar, rollback, AI health, config picker ([f3e9d3a](https://github.com/EnesDemir143/crisp/commit/f3e9d3a097bbc683bc9fb481a06d70645bba07b7))
* **modules:** modular architecture — common.sh + 12 modules ([a4ca78f](https://github.com/EnesDemir143/crisp/commit/a4ca78fbb7b7f5ffd63aa160986eb2f95a832a03))
* package manager update modules ([c5e2eab](https://github.com/EnesDemir143/crisp/commit/c5e2eabfeafe21f80ab4fac03bdf8d4997092051))
* **phase-04:** T1-T5 — orphan detection, version compare, batch update, recipes, uninstall ([123ccdd](https://github.com/EnesDemir143/crisp/commit/123ccdd06f1a67f463407f17885126ebc1a1ebdd))
* **phase-04:** T16-T19 — AI toolkit health with ML detection, GPU/CUDA check, release notifications ([02d0363](https://github.com/EnesDemir143/crisp/commit/02d0363862770c733f06896dfc1bab8bcd9c5423))
* **phase-04:** T20 — add orphan/radar/ai-health to main menu and help ([c4b7632](https://github.com/EnesDemir143/crisp/commit/c4b7632bf369da089767456841c5baa19c971d89))
* **phase-04:** T21 — interactive config module picker UI ([9481fdb](https://github.com/EnesDemir143/crisp/commit/9481fdbe0f7fd8c715b5012551958236dde9cf44))
* **phase-04:** T23 — config picker Bats tests ([c469c26](https://github.com/EnesDemir143/crisp/commit/c469c26c64177c5856c8e1f66ca4e7cac071ff52))
* **phase-04:** T24 — document Phase 4 features in README and crisp.conf ([eee9be0](https://github.com/EnesDemir143/crisp/commit/eee9be03280ef06a55e4d32f3b0d49e2f27a3f0d))
* **phase-04:** T6-T8 — deprecation radar with abandonment, alternatives, CI rot detection ([7f43f15](https://github.com/EnesDemir143/crisp/commit/7f43f15501a68a0552f47ac36011e80f3cf4bc85))
* **phase-04:** T9-T11,T22 — release notes digest in _run_module, atomic config save with backup ([cdf7709](https://github.com/EnesDemir143/crisp/commit/cdf7709d2eed8f5e338d469863a9e141065ce6aa))


### Bug Fixes

* **crisp:** resolve symlinks for CRISP_DIR ([0c17649](https://github.com/EnesDemir143/crisp/commit/0c17649215c820ec84dcc6fac668b2d1c7a32625))
* **tests:** replace hardcoded /opt/homebrew/bin/bash with bash for cross-platform CI ([3a4c15d](https://github.com/EnesDemir143/crisp/commit/3a4c15d7bb8ea538a3401600df50ab98c26a9915))
* **tui:** eliminate flicker — cursor_home instead of clear_screen ([086624d](https://github.com/EnesDemir143/crisp/commit/086624de70f584aaa7889a29bbed96449ff1ccd1))
* **tui:** Mole-style line clearing — eliminate all visual artifacts ([905e338](https://github.com/EnesDemir143/crisp/commit/905e338bccd00c1c6daa348ab8ffc1a6db22d72d))
* **tui:** use alternate screen buffer to prevent ASCII art stacking ([6f9ebe5](https://github.com/EnesDemir143/crisp/commit/6f9ebe5a7ada7eead6cfdd5acf2fe643adffaeb1))
* **ui:** printf %s → echo -e for proper ANSI color rendering ([fd93d0e](https://github.com/EnesDemir143/crisp/commit/fd93d0e3098e8e1f75093b05654954e6d11d5525))
