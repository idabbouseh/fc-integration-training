<#
.SYNOPSIS
  One-time setup so Claude Code can triage your Fieldglass mail in classic Outlook, read-only.

.DESCRIPTION
  Runs in Windows PowerShell 5.1 or PowerShell 7 as a normal user. It needs no admin rights,
  and it does not change Outlook settings or the registry.

  It does this, in order, and keeps going past any step it cannot finish:
    1. Checks for classic Outlook (OUTLOOK.EXE). The new Outlook (olk.exe) cannot be automated.
    2. Installs Claude Code with Anthropic's installer, if it is missing.
    3. Finds Python 3.12 or newer, or installs Python 3.12 for your user with winget.
    4. Installs the outlook-desktop-mcp package, pinned to the reviewed version, for your user.
    5. Registers it with Claude Code for all your projects (user scope).
    6. Adds permission rules to ~\.claude\settings.json: the 5 mail-reading tools are allowed,
       and the 16 mailbox-changing tools (send, reply, move, delete, mark, categorize, calendar,
       tasks, rules, attachments) are denied. A backup of the old file is kept.
    7. Installs the fg-mail-triage skill into ~\.claude\skills.
    8. Creates a work folder and prints the two commands left for you.

  A log is written to <WorkDir>\setup-log.txt.

.PARAMETER WorkDir
  Folder to start Claude Code in. Default: %USERPROFILE%\fg-mail

.PARAMETER AskBeforeReading
  Do not pre-allow the mail-reading tools. Claude Code will then ask before every mailbox read.

.EXAMPLE
  irm https://raw.githubusercontent.com/idabbouseh/fc-integration-training/refs/heads/claude/charming-bohr-77fpzh/fg-mail/setup-fg-mail.ps1 | iex

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-fg-mail.ps1 -AskBeforeReading
#>
[CmdletBinding()]
param(
    [string]$WorkDir = '',
    [switch]$AskBeforeReading
)

# ---------------------------------------------------------------- settings
$RepoRaw     = 'https://raw.githubusercontent.com/idabbouseh/fc-integration-training/refs/heads/claude/charming-bohr-77fpzh'
$SkillUrl    = "$RepoRaw/fg-mail/skills/fg-mail-triage/SKILL.md"
$McpPackage  = 'outlook-desktop-mcp==0.3.0'   # reviewed: local COM only, no network calls
$McpModule   = 'outlook_desktop_mcp'
$ServerName  = 'outlook-desktop'
$ReadTools   = @('list_accounts', 'list_emails', 'read_email', 'list_folders', 'search_emails')
$WriteTools  = @('send_email', 'reply_email', 'move_email', 'mark_as_read', 'mark_as_unread', 'set_category',
                 'save_attachment', 'create_event', 'create_meeting', 'update_event', 'delete_event',
                 'respond_to_meeting', 'create_task', 'complete_task', 'delete_task', 'toggle_rule')

$Results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$Step, [string]$Status, [string]$Detail) {
    $Results.Add([pscustomobject]@{ Step = $Step; Status = $Status; Detail = $Detail })
    $color = @{ 'OK' = 'Green'; 'WARN' = 'Yellow'; 'FAIL' = 'Red'; 'SKIP' = 'DarkYellow' }[$Status]
    Write-Host ("[{0}] {1}: {2}" -f $Status, $Step, $Detail) -ForegroundColor $color
}
function Write-Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $local   = Join-Path $env:USERPROFILE '.local\bin'
    $env:Path = (@($machine, $user, $local) | Where-Object { $_ }) -join ';'
}

# ---------------------------------------------------------------- 0. preflight
if ($env:OS -ne 'Windows_NT') {
    Write-Host 'This script is for Windows only. On a Mac, import the skill into Joule Work Desktop instead (see RUNBOOK.md).' -ForegroundColor Red
    return
}
if (-not $WorkDir) { $WorkDir = Join-Path $env:USERPROFILE 'fg-mail' }
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host 'PowerShell is in Constrained Language Mode on this machine, so this script cannot run.' -ForegroundColor Red
    Write-Host 'Follow the manual runbook (RUNBOOK.md) instead, or ask IT about running PowerShell scripts.' -ForegroundColor Red
    return
}
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$logFile = Join-Path $WorkDir 'setup-log.txt'
try { Start-Transcript -Path $logFile -Append | Out-Null } catch { }

Write-Host ''
Write-Host 'Fieldglass mail triage: one-time setup (read-only mailbox access for Claude Code)' -ForegroundColor Cyan
Write-Host "Work folder: $WorkDir"

# ---------------------------------------------------------------- 1. Outlook
Write-Step '1/8 Outlook'
$classicInstalled = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE') -or
                    (Test-Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE')
$classicRunning = [bool](Get-Process -Name 'OUTLOOK' -ErrorAction SilentlyContinue)
$newRunning     = [bool](Get-Process -Name 'olk' -ErrorAction SilentlyContinue)
if ($classicRunning) {
    Add-Result 'Outlook' 'OK' 'Classic Outlook (OUTLOOK.EXE) is running.'
} elseif ($newRunning) {
    Add-Result 'Outlook' 'WARN' "You are on the new Outlook. Turn off the 'New Outlook' toggle (top right) to switch to classic Outlook. Setup continues; the live check is skipped."
} elseif ($classicInstalled) {
    Add-Result 'Outlook' 'WARN' 'Classic Outlook is installed but not running. Open it before using Claude. The live check is skipped.'
} else {
    Add-Result 'Outlook' 'WARN' 'Classic Outlook was not found. The mail tools need classic Outlook (OUTLOOK.EXE).'
}

# ---------------------------------------------------------------- 2. Claude Code
Write-Step '2/8 Claude Code'
function Get-ClaudeExe {
    $cmd = Get-Command 'claude' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $p = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path $p) { return $p }
    return $null
}
$claude = Get-ClaudeExe
if (-not $claude) {
    Write-Host 'Installing Claude Code with the native installer (no admin needed)...'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex'
    Update-SessionPath
    $claude = Get-ClaudeExe
    if (-not $claude -and (Get-Command 'winget' -ErrorAction SilentlyContinue)) {
        Write-Host 'Native installer did not finish; trying winget...'
        & winget install --id Anthropic.ClaudeCode -e --accept-package-agreements --accept-source-agreements
        Update-SessionPath
        $claude = Get-ClaudeExe
    }
}
if ($claude) {
    $ver = (& $claude --version 2>&1 | Out-String).Trim()
    Add-Result 'Claude Code' 'OK' "$ver at $claude"
} else {
    Add-Result 'Claude Code' 'FAIL' 'Could not install Claude Code. Run: irm https://claude.ai/install.ps1 | iex, then rerun this script.'
}

# ---------------------------------------------------------------- 3. Python
Write-Step '3/8 Python 3.12+'
function Test-PythonExe([string]$Exe) {
    if (-not $Exe) { return $null }
    $out = & $Exe -c "import sys; print('%d.%d|%s' % (sys.version_info[0], sys.version_info[1], sys.executable))" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $out) { return $null }
    $parts = ([string]$out).Trim().Split('|')
    if ([version]$parts[0] -ge [version]'3.12') { return $parts[1] }
    return $null
}
function Get-PythonExe {
    if (Get-Command 'py' -ErrorAction SilentlyContinue) {
        foreach ($v in @('3.13', '3.12')) {
            $out = & py "-$v" -c 'import sys; print(sys.executable)' 2>$null
            if ($LASTEXITCODE -eq 0 -and $out) { return ([string]$out).Trim() }
        }
    }
    foreach ($name in @('python', 'python3')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { $exe = Test-PythonExe $cmd.Source; if ($exe) { return $exe } }
    }
    foreach ($v in @('313', '312')) {
        $exe = Test-PythonExe (Join-Path $env:LOCALAPPDATA "Programs\Python\Python$v\python.exe")
        if ($exe) { return $exe }
    }
    return $null
}
$py = Get-PythonExe
if (-not $py -and (Get-Command 'winget' -ErrorAction SilentlyContinue)) {
    Write-Host 'Python 3.12+ not found. Installing Python 3.12 for your user with winget...'
    & winget install --id Python.Python.3.12 -e --scope user --accept-package-agreements --accept-source-agreements --silent
    Update-SessionPath
    $py = Get-PythonExe
}
if ($py) {
    Add-Result 'Python' 'OK' $py
} else {
    Add-Result 'Python' 'FAIL' 'Python 3.12+ not found. Install it from python.org (per-user install, tick "Add python.exe to PATH"), then rerun.'
}

# ---------------------------------------------------------------- 4. Outlook MCP package
Write-Step "4/8 Outlook MCP server ($McpPackage)"
$mcpReady = $false
if ($py) {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        & $py -m pip install --user --disable-pip-version-check --only-binary=:all: pywin32 'mcp[cli]>=1.26.0'
    }
    & $py -m pip install --user --disable-pip-version-check --upgrade $McpPackage
    & $py -c "import $McpModule, win32com.client" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $mcpReady = $true
        Add-Result 'Outlook MCP' 'OK' "$McpPackage installed for your user."
    } else {
        Add-Result 'Outlook MCP' 'FAIL' "pip install or import failed. See $logFile. Common causes: a proxy blocking pypi.org, or a Python that refuses package installs (PEP 668)."
    }
} else {
    Add-Result 'Outlook MCP' 'SKIP' 'Needs Python.'
}

# ---------------------------------------------------------------- 5. register with Claude Code
Write-Step '5/8 Register the server with Claude Code'
if ($claude -and $mcpReady) {
    & $claude mcp remove $ServerName --scope user 2>$null | Out-Null
    # '--' is quoted so Windows PowerShell 5.1 passes it to claude instead of treating it as its own end-of-parameters marker.
    & $claude mcp add --scope user $ServerName '--' $py -m $McpModule
    if ($LASTEXITCODE -eq 0) {
        Add-Result 'Register' 'OK' "'$ServerName' runs: $py -m $McpModule"
    } else {
        Add-Result 'Register' 'FAIL' "Run manually: claude mcp add --scope user $ServerName -- `"$py`" -m $McpModule"
    }
} else {
    Add-Result 'Register' 'SKIP' 'Needs Claude Code and the Outlook MCP package.'
}

# ---------------------------------------------------------------- 6. permission rules
Write-Step '6/8 Read-only permission rules'
if ($py) {
    # Running the skill is allowed so Claude Code doesn't stop to ask before loading it.
    $allow = @('Skill(fg-mail-triage)')
    if (-not $AskBeforeReading) { $allow += $ReadTools | ForEach-Object { "mcp__${ServerName}__$_" } }
    $deny = $WriteTools | ForEach-Object { "mcp__${ServerName}__$_" }
    # Arguments carry a name= prefix because Windows PowerShell 5.1 drops empty arguments to native programs.
    $merge = @'
import json, os, shutil, sys
args = dict(a.split("=", 1) for a in sys.argv[1:] if "=" in a)
allow = [r for r in args.get("allow", "").split(",") if r]
deny = [r for r in args.get("deny", "").split(",") if r]
path = os.path.join(os.path.expanduser("~"), ".claude", "settings.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
data = {}
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8-sig") as f:
            data = json.load(f)
    except Exception as e:
        print("settings.json is not plain JSON, left unchanged: %s" % e)
        sys.exit(2)
    shutil.copyfile(path, path + ".bak-fg-mail")
perms = data.setdefault("permissions", {})
for key, rules in (("allow", allow), ("deny", deny)):
    current = perms.setdefault(key, [])
    current.extend(r for r in rules if r not in current)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
print("updated " + path)
'@
    $mergeFile = Join-Path $env:TEMP 'fg-mail-merge-settings.py'
    Set-Content -Path $mergeFile -Value $merge -Encoding ASCII
    & $py $mergeFile ('allow=' + ($allow -join ',')) ('deny=' + ($deny -join ','))
    $code = $LASTEXITCODE
    Remove-Item $mergeFile -ErrorAction SilentlyContinue
    if ($code -eq 0) {
        $what = if ($AskBeforeReading) { 'mail reads will ask first' } else { "$($ReadTools.Count) read tools allowed" }
        Add-Result 'Permissions' 'OK' "$what; $($WriteTools.Count) mailbox-changing tools denied."
    } else {
        Add-Result 'Permissions' 'FAIL' 'Could not update ~\.claude\settings.json. Add the deny rules from RUNBOOK.md by hand.'
    }
} else {
    Add-Result 'Permissions' 'SKIP' 'Needs Python.'
}

# ---------------------------------------------------------------- 7. skill
Write-Step '7/8 Install the fg-mail-triage skill'
$skillDir  = Join-Path $env:USERPROFILE '.claude\skills\fg-mail-triage'
$skillFile = Join-Path $skillDir 'SKILL.md'
New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
$localSkill = $null
if ($PSScriptRoot) { $localSkill = Join-Path $PSScriptRoot 'skills\fg-mail-triage\SKILL.md' }
try {
    if (Test-Path $skillFile) { Copy-Item $skillFile "$skillFile.bak" -Force }
    if ($localSkill -and (Test-Path $localSkill)) {
        Copy-Item $localSkill $skillFile -Force
        Add-Result 'Skill' 'OK' "Copied from $localSkill"
    } else {
        Invoke-WebRequest -Uri $SkillUrl -OutFile $skillFile -UseBasicParsing
        Add-Result 'Skill' 'OK' "Downloaded to $skillFile"
    }
} catch {
    Add-Result 'Skill' 'FAIL' "Could not get SKILL.md ($($_.Exception.Message)). Copy it to $skillFile by hand."
}

# ---------------------------------------------------------------- 8. live check
Write-Step '8/8 Live check'
$classicRunning = [bool](Get-Process -Name 'OUTLOOK' -ErrorAction SilentlyContinue)
if ($claude -and $mcpReady -and $classicRunning) {
    Push-Location $WorkDir
    $list = (& $claude mcp list 2>&1 | Out-String)
    Pop-Location
    $line = ($list -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($ServerName) } | Select-Object -First 1)
    if ($line -cmatch 'Connected') {
        Add-Result 'Live check' 'OK' $line.Trim()
    } else {
        Add-Result 'Live check' 'WARN' "Server not connected yet: $($line). If Outlook shows a 'program is trying to access' prompt, choose Allow."
    }
} else {
    Add-Result 'Live check' 'SKIP' 'Needs Claude Code, the Outlook MCP package and classic Outlook running.'
}

# ---------------------------------------------------------------- summary
Write-Host ''
Write-Host 'Summary' -ForegroundColor Cyan
$Results | Format-Table -AutoSize -Wrap | Out-String | Write-Host
$failed = @($Results | Where-Object { $_.Status -eq 'FAIL' }).Count
if ($failed -eq 0) {
    Write-Host 'Setup finished. Two things left for you:' -ForegroundColor Green
} else {
    Write-Host "Setup finished with $failed problem(s) above. Fix those, rerun this script, then:" -ForegroundColor Yellow
}
Write-Host ''
Write-Host "  cd `"$WorkDir`""
Write-Host '  claude                               # first time only: type /login, finish in the browser, then /exit'
Write-Host '  claude remote-control --name "FG mail"'
Write-Host ''
Write-Host 'Then open claude.ai/code or the Claude app, pick "FG mail", and ask:'
Write-Host '  triage my Fieldglass mail from the last week'
Write-Host ''
Write-Host 'Keep classic Outlook and this terminal open while you use it. If Outlook asks whether to allow'
Write-Host "access, choose 'Allow access for 10 minutes'. Log: $logFile"
try { Stop-Transcript | Out-Null } catch { }
