#compdef crisp
# crisp zsh completion
# Install: cp completions/crisp.zsh ~/.zsh/completions/_crisp
# Add ~/.zsh/completions to fpath in ~/.zshrc if needed:
#   fpath=(~/.zsh/completions $fpath)

_crisp() {
  local subcommands=(
    'all:Run all enabled modules'
    'quick:Quick update (brew/pip/npm)'
    'repos:Local repository status'
    'cron:Schedule auto-update'
    'config:Configure modules'
    'help:Help and about'
    'list:List available modules'
    'version:Show version info'
    'update:Self-update crisp'
    'setup-path:Add crisp to PATH'
    '--help:Show help message'
    '--version:Show version'
    '--dry-run:Preview without changes'
  )

  local modules=()
  if [[ -f ~/.config/crisp/crisp.conf ]]; then
    local conf_modules
    conf_modules=$(grep -o 'CRISP_MODULES="[^"]*"' ~/.config/crisp/crisp.conf 2>/dev/null \
      | sed 's/CRISP_MODULES="//;s/"//' || echo "")
    for m in $conf_modules; do
      modules+=("${m}:Run ${m} module")
    done
  fi

  _arguments \
    "1: :->command" \
    "*::arg:->args"

  case "$state" in
    command)
      _describe -t commands 'crisp command' subcommands
      _describe -t modules 'crisp module' modules
      ;;
    args)
      _message 'no more arguments'
      ;;
  esac
}

_crisp "$@"
