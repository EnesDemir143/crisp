# crisp bash completion
# Install: source completions/crisp.bash
#  or: cp completions/crisp.bash ~/.local/share/bash-completion/completions/crisp

_crisp_completion() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local subcommands="all quick repos cron config help list version update setup-path --help --version --dry-run"

  local modules=""
  if [[ -f ~/.config/crisp/crisp.conf ]]; then
    modules=$(grep -o 'CRISP_MODULES="[^"]*"' ~/.config/crisp/crisp.conf 2>/dev/null \
      | sed 's/CRISP_MODULES="//;s/"//' || echo "")
  fi

  if [[ -z "$modules" ]]; then
    modules="brew pip npm"
  fi

  case "$prev" in
    crisp)
      COMPREPLY=( $(compgen -W "$subcommands $modules" -- "$cur") )
      ;;
    *)
      COMPREPLY=( $(compgen -W "$subcommands $modules" -- "$cur") )
      ;;
  esac
}

complete -F _crisp_completion crisp
