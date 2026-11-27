<#
Installs the ElastiCORE agent kit for Codex CLI on Windows, with Git Bash.

  powershell -ExecutionPolicy Bypass -File codex\install.ps1               for you: ~\.agents\skills\, ~\.codex\ ($env:CODEX_HOME when set)
  powershell -ExecutionPolicy Bypass -File codex\install.ps1 -Project      for the project in the current folder
  powershell -ExecutionPolicy Bypass -File codex\install.ps1 -NoHooks      the skills and the agents, no hooks
  powershell -ExecutionPolicy Bypass -File codex\install.ps1 -AgentsOnly   the agents alone, beside the plugin

Runs codex/install.sh with Git Bash, which the hooks need anyway: it copies the
skills, the agents and the hook script, and writes hooks.json unless there is one;
the hooks call the Git Bash found here. --project, --no-hooks and --agents-only work
as well.
#>
param(
    [switch]$Project,
    [switch]$NoHooks,
    [switch]$AgentsOnly,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

foreach ($arg in $Rest) {
    if ($arg -eq '--project') { $Project = $true }
    elseif ($arg -eq '--no-hooks') { $NoHooks = $true }
    elseif ($arg -eq '--agents-only') { $AgentsOnly = $true }
    else { [Console]::Error.WriteLine("Unknown option: $arg - use -Project, -NoHooks, -AgentsOnly, or no option."); exit 2 }
}

# Git Bash, the launcher bin\bash.exe: the bash on the PATH may be WSL's, which cannot read
# a Windows path. The same places as the plugin's hooks look in.
$candidates = @(
    (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
    $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe' }),
    (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'),
    (Join-Path $env:USERPROFILE 'scoop\apps\git\current\bin\bash.exe')
)
foreach ($git in @(Get-Command git.exe -ErrorAction SilentlyContinue)) {
    $folder = Split-Path (Split-Path $git.Source)
    $candidates += (Join-Path $folder 'bin\bash.exe'), (Join-Path (Split-Path $folder) 'bin\bash.exe')
}
$bash = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $bash) {
    [Console]::Error.WriteLine('Git for Windows is needed: the hooks run in Git Bash. Install it, then run this again.')
    exit 1
}

$script = Join-Path $PSScriptRoot 'install.sh'
$arguments = @($script)
if ($Project) { $arguments += '--project' }
if ($NoHooks) { $arguments += '--no-hooks' }
if ($AgentsOnly) { $arguments += '--agents-only' }
$env:ELASTICORE_BASH = $bash
& $bash @arguments
exit $LASTEXITCODE
