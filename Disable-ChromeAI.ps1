#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Disables Gemini and other AI features in Google Chrome via policies, hosts, Local State flags, and a version-change reminder.
.NOTES
  Unlicense. Close Chrome before running. Restart Chrome afterward and verify chrome://policy and chrome://flags.
#>

$ErrorActionPreference = 'Stop'

# --- Policies (machine) ---
$policyPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
if (-not (Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}

$policies = @{
    AIModeSettings                      = 1
    AutofillPredictionSettings          = 2
    AutomatedPasswordChangeSettings     = 2
    ChromeSuggestionsSettings           = 2
    CreateThemesSettings                = 2
    DevToolsGenAiSettings               = 2
    FindAndFillWithGeminiSettings       = 2
    GeminiActOnWebSettings              = 1
    GeminiSettings                      = 1
    GeminiSparkSettings                 = 1
    GenAILocalFoundationalModelSettings = 1
    HelpMeWriteSettings                 = 2
    HistorySearchSettings               = 2
    SearchContentSharingSettings        = 1
    TabCompareSettings                  = 2
    ThirdPartyAiChatSettings            = 1
    TryOnYouSettings                    = 2
    VoiceTypingSettings                 = 2
}

foreach ($name in $policies.Keys) {
    New-ItemProperty -Path $policyPath -Name $name -Value $policies[$name] -PropertyType DWord -Force | Out-Null
}

Write-Host 'Policies applied.' -ForegroundColor Green

# --- Hosts ---
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
if ($hostsContent -notmatch 'gemini\.google\.com') {
    Add-Content -Path $hostsPath -Value "`r`n# Block Gemini web interfaces`r`n127.0.0.1 gemini.google.com`r`n127.0.0.1 aistudio.google.com`r`n"
    Write-Host 'Hosts entries added.' -ForegroundColor Green
} else {
    Write-Host 'Hosts entries already present.' -ForegroundColor Yellow
}

# --- Local State flags (user profile) ---
$localStatePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
if (Test-Path $localStatePath) {
    $json = Get-Content $localStatePath -Raw | ConvertFrom-Json
    if (-not $json.browser) { $json | Add-Member -NotePropertyName browser -NotePropertyValue ([pscustomobject]@{}) }
    $existing = @()
    if ($json.browser.enabled_labs_experiments) {
        $existing = @($json.browser.enabled_labs_experiments)
    }

    $desired = @(
        'aim-3p-entrypoint@2',
        'omnibox-dynamic-ai-mode-button@2',
        'ntp-realbox-dynamic-ai-mode-button@2',
        'omnibox-ai-mode-space-does-not-activate@1',
        'prompt-api@2',
        'geic-enabled@2',
        'glic-spark-settings-accessible-labels@2',
        'skills@2',
        'sync-gemini-threads@2'
        # Extend this list with additional flag@N entries as needed.
        # @0 = Default, @1 = Enabled, @2 = Disabled for most simple flags.
    )

    $merged = ($existing + $desired) | Select-Object -Unique
    $json.browser.enabled_labs_experiments = $merged
    $json | ConvertTo-Json -Depth 20 | Set-Content $localStatePath -Encoding UTF8
    Write-Host 'Local State flags updated.' -ForegroundColor Green
} else {
    Write-Host 'Local State not found (Chrome not yet run?). Skipping flags.' -ForegroundColor Yellow
}

# --- Version-change reminder script + scheduled task ---
$scriptDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$scriptPath = "$scriptDir\CheckChromeUpdate.ps1"
$scriptContent = @'
$stateFile = "$env:USERPROFILE\chrome_version.txt"
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chromePath)) { exit }
$current = (Get-Item $chromePath).VersionInfo.ProductVersion
$last = if (Test-Path $stateFile) { (Get-Content $stateFile -Raw).Trim() } else { "" }
if ($current -ne $last) {
    Set-Content -Path $stateFile -Value $current -NoNewline
    msg $env:USERNAME "Chrome updated to $current. Recheck chrome://policy and chrome://flags for new AI features."
}
'@
New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'ChromeUpdateCheck' -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Write-Host 'Scheduled task ChromeUpdateCheck created (daily 09:00, notifies only on version change).' -ForegroundColor Green

Write-Host '`nDone. Close any remaining Chrome processes, restart Chrome, then check chrome://policy and chrome://flags.' -ForegroundColor Cyan
