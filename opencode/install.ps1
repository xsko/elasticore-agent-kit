<#
Installs the ElastiCORE agent kit for opencode, for the current user.

  powershell -ExecutionPolicy Bypass -File opencode\install.ps1            into ~\.config\opencode\ ($env:XDG_CONFIG_HOME\opencode\ when set)
  powershell -ExecutionPolicy Bypass -File opencode\install.ps1 -Project   into .\.opencode\ of the current directory

Copies the plugin, the hook script, the elasticore skill, the agents and the
commands, and overwrites those files when they are there already - run it
again to update. It deletes nothing. --project works as well as -Project.
#>
param(
    [switch]$Project,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

foreach ($arg in $Rest) {
    if ($arg -eq '--project') { $Project = $true }
    else { [Console]::Error.WriteLine("Unknown option: $arg - use -Project, or no option."); exit 2 }
}

if ($Project) {
    $target = Join-Path (Get-Location).Path '.opencode'
} else {
    $config = $env:XDG_CONFIG_HOME
    if (-not $config) { $config = Join-Path $HOME '.config' }
    $target = Join-Path $config 'opencode'
}

$here = $PSScriptRoot
$kit = Join-Path (Split-Path -Parent $here) 'plugins\elasticore'
if (-not (Test-Path -LiteralPath (Join-Path $kit 'hooks\elasticore-hook.sh')) -or
    -not (Test-Path -LiteralPath (Join-Path $here 'plugins\elasticore.js'))) {
    [Console]::Error.WriteLine("Run this script from a checkout of the ElastiCORE agent kit: $kit is missing.")
    exit 1
}

# Copies one file to a path under the target, byte for byte.
function Copy-KitFile([string]$Source, [string]$Relative) {
    $destination = Join-Path $target $Relative
    $folder = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    Copy-Item -LiteralPath $Source -Destination $destination -Force
    Write-Output "  $Relative"
}

Write-Output "Installing the ElastiCORE agent kit for opencode into $target"
Copy-KitFile (Join-Path $here 'plugins\elasticore.js') 'plugins\elasticore.js'
Copy-KitFile (Join-Path $kit 'hooks\elasticore-hook.sh') 'elasticore-kit\elasticore-hook.sh'
$skill = (Resolve-Path -LiteralPath (Join-Path $kit 'skills\elasticore')).Path
Get-ChildItem -LiteralPath $skill -Recurse -File | Sort-Object FullName | ForEach-Object {
    Copy-KitFile $_.FullName ('skills\elasticore\' + $_.FullName.Substring($skill.Length).TrimStart('\', '/'))
}
Get-ChildItem -LiteralPath (Join-Path $here 'agents') -Filter '*.md' -File | ForEach-Object {
    Copy-KitFile $_.FullName ('agents\' + $_.Name)
}
Get-ChildItem -LiteralPath (Join-Path $here 'commands') -Filter '*.md' -File | ForEach-Object {
    Copy-KitFile $_.FullName ('commands\' + $_.Name)
}
Write-Output 'Done. Start a new opencode session to load it; opencode\README.md has the settings to add to opencode.json.'
