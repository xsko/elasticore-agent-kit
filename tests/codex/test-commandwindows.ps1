<#
Runs the Codex plugin's Windows hook command the way Codex does - Windows PowerShell, the payload
on stdin - and checks that it finds Git Bash and runs the hook script, and that without any Git
Bash it says so and fails instead of letting everything through in silence.

  powershell -ExecutionPolicy Bypass -File tests\codex\test-commandwindows.ps1      Windows only

For the "only git.exe on PATH" and "no Git" cases the usual folders are replaced in the command by
a folder that does not exist: Windows sets ProgramFiles anew for a child process.
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$plugin = Join-Path $repo 'plugins\elasticore'
$work = Join-Path ([IO.Path]::GetTempPath()) ('elasticore-cmdwin-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$project = Join-Path $work 'shop'
$dto = Join-Path $project 'src\main\java\com\acme\shop\ProductDTO.java'
New-Item -ItemType Directory -Force (Split-Path -Parent $dto) | Out-Null
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $project 'build.gradle'), "plugins { id 'io.elasticore' version '3.0.261127' }`n", $enc)
[IO.File]::WriteAllText($dto, "//ecd:-1375193215H20261127080000_V3.0`npackage com.acme.shop;`n`npublic class ProductDTO {}`n", $enc)

$json = Get-Content -Raw (Join-Path $plugin 'hooks\codex-hooks.json') | ConvertFrom-Json
$cmd = $json.hooks.PreToolUse[0].hooks[0].commandWindows
$payload = (@{ session_id = 'cw'; turn_id = 't'; cwd = $project; hook_event_name = 'PreToolUse'; tool_name = 'apply_patch'
               tool_input = @{ command = "*** Begin Patch`n*** Update File: src/main/java/com/acme/shop/ProductDTO.java`n@@`n-a`n+b`n*** End Patch" }
               tool_use_id = 'x' } | ConvertTo-Json -Compress)
$env:PLUGIN_ROOT = $plugin
$env:CLAUDE_PLUGIN_DATA = Join-Path $work 'data'
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$failed = 0

function Run([string]$c) {
    # A process of its own, the payload on its stdin, as Codex starts one. -EncodedCommand:
    # Windows PowerShell 5.1 would strip the inner quotes of a -Command argument.
    $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($c))
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $ps
    $info.Arguments = "-NoProfile -NonInteractive -EncodedCommand $b64"
    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($info)
    $p.StandardInput.Write($payload)
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ Out = $out; Exit = $p.ExitCode }
}
function Check([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) { return }
    $script:failed++
    Write-Output "FAIL $name`n  $($detail.Substring(0, [Math]::Min(400, $detail.Length)))"
}

$r = Run $cmd
Check 'Git Bash found: the edit of a //ecd: file is refused' ($r.Exit -eq 0 -and $r.Out -match '"permissionDecision":"deny"') $r.Out
$none = $cmd.Replace('$env:ProgramFiles\Git', 'C:\nowhere\Git').Replace('${env:ProgramFiles(x86)}\Git', 'C:\nowhere\Git').Replace('$env:LOCALAPPDATA\Programs\Git', 'C:\nowhere\Git').Replace('$env:USERPROFILE\scoop', 'C:\nowhere\scoop')
$git = Get-Command git.exe -ErrorAction SilentlyContinue
$saved = $env:PATH
try {
    if ($git) {
        $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot;" + (Split-Path -Parent $git.Source)
        $r = Run $none
        Check 'only git.exe on PATH: Git Bash beside it is found' ($r.Exit -eq 0 -and $r.Out -match '"permissionDecision":"deny"') $r.Out
    }
    $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
    $r = Run $none
    Check 'no Git Bash: the hook fails, with the reason' ($r.Exit -ne 0 -and $r.Out -match 'no Git Bash found') $r.Out
} finally {
    $env:PATH = $saved
}
foreach ($event in 'pre-edit', 'pre-bash', 'post-edit', 'post-bash', 'stop') {
    $all = @($json.hooks.PreToolUse + $json.hooks.PostToolUse + $json.hooks.Stop | ForEach-Object { $_.hooks } | Where-Object { $_.commandWindows -match " $event codex\}" })
    Check "a commandWindows for $event, the same search" ($all.Count -eq 1 -and $all[0].commandWindows.Replace(" $event codex}", ' X codex}') -eq $cmd.Replace(' pre-edit codex}', ' X codex}')) "$($all.Count)"
}
Write-Output "$failed failed (fixtures in $work)"
exit $failed
