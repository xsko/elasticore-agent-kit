<#
Installs the ElastiCORE agent kit for pi or oh-my-pi (omp) on Windows, with Git Bash.

  powershell -ExecutionPolicy Bypass -File pi\install.ps1                 pi, for you: ~\.pi\agent\ ($env:PI_CODING_AGENT_DIR when set)
  powershell -ExecutionPolicy Bypass -File pi\install.ps1 -Project        pi, for the project in the current folder: .pi\, .agents\skills\
  powershell -ExecutionPolicy Bypass -File pi\install.ps1 -Omp            omp, for you: ~\.omp\agent\ ($env:PI_CODING_AGENT_DIR when set)
  powershell -ExecutionPolicy Bypass -File pi\install.ps1 -Omp -Project   omp, for the project in the current folder: .omp\

Runs pi/install.sh with Git Bash, which the hooks need anyway: it copies the
extension, the hook script, the skills and (omp) the agents, and records the Git
Bash found here for the extension to run the hook script with. --project and
--omp work as well.
#>
param(
    [switch]$Project,
    [switch]$Omp,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

foreach ($arg in $Rest) {
    if ($arg -eq '--project') { $Project = $true }
    elseif ($arg -eq '--omp') { $Omp = $true }
    else { [Console]::Error.WriteLine("Unknown option: $arg - use -Project, -Omp, or no option."); exit 2 }
}

# Git Bash, the launcher bin\bash.exe: the bash on the PATH may be WSL's, which cannot read
# a Windows path. The same places as codex\install.ps1 and the extension look in.
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
if ($Omp) { $arguments += '--omp' }
$env:ELASTICORE_BASH = $bash
& $bash @arguments
exit $LASTEXITCODE
