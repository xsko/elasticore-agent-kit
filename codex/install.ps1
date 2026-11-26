<#
Installs the ElastiCORE agent kit for Codex CLI on Windows, with Git Bash.

  powershell -ExecutionPolicy Bypass -File codex\install.ps1             for you: ~\.agents\skills\, ~\.codex\ ($env:CODEX_HOME when set)
  powershell -ExecutionPolicy Bypass -File codex\install.ps1 -Project    for the project in the current folder
  powershell -ExecutionPolicy Bypass -File codex\install.ps1 -NoHooks    skills and agents only

Runs codex/install.sh with Git Bash, which the hooks need anyway: it copies the
skills, the agents and the hook script, and writes hooks.json unless there is one.
--project and --no-hooks work as well as -Project and -NoHooks.
#>
param(
    [switch]$Project,
    [switch]$NoHooks,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

foreach ($arg in $Rest) {
    if ($arg -eq '--project') { $Project = $true }
    elseif ($arg -eq '--no-hooks') { $NoHooks = $true }
    else { [Console]::Error.WriteLine("Unknown option: $arg - use -Project, -NoHooks, or no option."); exit 2 }
}

# Git Bash: the bash on the PATH may be WSL's, which cannot read a Windows path.
$bash = $null
foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
    if (-not $root) { continue }
    $candidate = Join-Path $root 'Git\bin\bash.exe'
    if (Test-Path -LiteralPath $candidate) { $bash = $candidate; break }
}
if (-not $bash) {
    [Console]::Error.WriteLine('Git for Windows is needed: the hooks run in Git Bash. Install it, then run this again.')
    exit 1
}

$script = Join-Path $PSScriptRoot 'install.sh'
$arguments = @($script)
if ($Project) { $arguments += '--project' }
if ($NoHooks) { $arguments += '--no-hooks' }
& $bash @arguments
exit $LASTEXITCODE
