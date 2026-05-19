# crisp PowerShell completion
# Install: . completions/crisp.ps1
#  or add to $PROFILE: echo '. /path/to/completions/crisp.ps1' >> $PROFILE

Register-ArgumentCompleter -CommandName crisp -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $subcommands = @(
        'all', 'quick', 'repos', 'cron', 'config', 'help',
        'list', 'version', 'update', 'setup-path',
        '--help', '--version', '--dry-run'
    )

    $modules = @('brew', 'pip', 'npm')

    if (Test-Path "$env:HOME/.config/crisp/crisp.conf") {
        $content = Get-Content "$env:HOME/.config/crisp/crisp.conf" -Raw
        if ($content -match 'CRISP_MODULES="([^"]*)"') {
            $modules = $Matches[1] -split '\s+'
        }
    }

    $allValues = $subcommands + $modules
    $allValues | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
