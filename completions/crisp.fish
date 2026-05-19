# crisp fish completion
# Install: cp completions/crisp.fish ~/.config/fish/completions/crisp.fish

complete -c crisp -f

# Core subcommands
complete -c crisp -n __fish_use_subcommand -a all      -d "Run all enabled modules"
complete -c crisp -n __fish_use_subcommand -a quick    -d "Quick update (brew/pip/npm)"
complete -c crisp -n __fish_use_subcommand -a repos    -d "Local repository status"
complete -c crisp -n __fish_use_subcommand -a cron     -d "Schedule auto-update"
complete -c crisp -n __fish_use_subcommand -a config   -d "Configure modules"
complete -c crisp -n __fish_use_subcommand -a help     -d "Help and about"
complete -c crisp -n __fish_use_subcommand -a list     -d "List available modules"
complete -c crisp -n __fish_use_subcommand -a version  -d "Show version info"
complete -c crisp -n __fish_use_subcommand -a update   -d "Self-update crisp"
complete -c crisp -n __fish_use_subcommand -a setup-path -d "Add crisp to PATH"

# Flags
complete -c crisp -n __fish_use_subcommand -a '--help'    -d "Show help message"
complete -c crisp -n __fish_use_subcommand -a '--version' -d "Show version"
complete -c crisp -n __fish_use_subcommand -a '--dry-run' -d "Preview without changes"

# Module names (dynamic)
function __fish_crisp_modules
    if test -f ~/.config/crisp/crisp.conf
        string match -r 'CRISP_MODULES="([^"]*)"' < ~/.config/crisp/crisp.conf | string replace -r 'CRISP_MODULES="|"' ''
    end
end

for mod in (__fish_crisp_modules)
    complete -c crisp -n __fish_use_subcommand -a "$mod" -d "Run $mod module"
end
