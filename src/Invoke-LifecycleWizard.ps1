#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Onboarding', 'Offboarding')]
    [string]$Mode = 'Onboarding',

    [string]$ConfigPath,

    [hashtable]$User = @{
        Name       = 'Jane Doe'
        Title      = 'Analyst'
        Department = 'Operations'
        Manager    = 'Pat Lead'
        StartDate  = (Get-Date).ToString('yyyy-MM-dd')
        UPN        = 'jane.doe@example.com'
        LastDay    = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
        ForwardTo  = 'pat.lead@example.com'
        AutoReply  = 'true'
        Equipment  = 'laptop'
    },

    [bool]$DryRun = $true,

    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'lib/Common.ps1')
. (Join-Path $root 'lib/Connectors.ps1')
. (Join-Path $root 'steps/Onboarding.Steps.ps1')
. (Join-Path $root 'steps/Offboarding.Steps.ps1')

if (-not $ConfigPath) {
    $ConfigPath = Join-Path (Split-Path $root -Parent) 'config/lifecycle.example.psd1'
}
$config = Import-PowerShellDataFile -Path $ConfigPath

$ctx = @{
    Config    = $config
    User      = $User
    DryRun    = $DryRun
    IsWindows = ($env:OS -eq 'Windows_NT')
    Log       = @()
}

$steps = switch ($Mode) {
    'Onboarding'  { Get-OnboardingSteps }
    'Offboarding' { Get-OffboardingSteps }
}
$total = $steps.Count

$logPath = New-LogFile -Root (Split-Path $root -Parent) -Mode $Mode

Write-Banner ("User Lifecycle Wizard - {0}" -f $Mode)
Write-Detail 'Organization' $config.Organization
$userLabel = if ($User.ContainsKey('Name') -and $User.Name) { $User.Name } elseif ($User.ContainsKey('UPN') -and $User.UPN) { $User.UPN } else { '(unspecified)' }
Write-Detail 'User' $userLabel
Write-Detail 'Execution' ("DryRun={0}" -f $DryRun)
Write-Host ''
Write-Host 'Planned steps:' -ForegroundColor Cyan
for ($i = 0; $i -lt $total; $i++) {
    Write-Host ("  {0}. [{1}] {2}" -f ($i + 1), $steps[$i].Type, $steps[$i].Title) -ForegroundColor Gray
}

if (-not (Confirm-Proceed -Prompt 'Run these steps?' -NonInteractive:$NonInteractive)) {
    Write-Host 'Aborted by operator.' -ForegroundColor Red
    exit 2
}

$followups = @()
$halted = $false
for ($i = 0; $i -lt $total; $i++) {
    $s = $steps[$i]
    Write-StepHeader -Index ($i + 1) -Total $total -Title $s.Title -Type $s.Type
    Write-Detail 'What' $s.Description
    Write-Detail 'Verify' $s.Verify
    $result = & $s.Action $ctx
    if ($result) {
        $isStop = "$result".StartsWith('[STOP]')
        Write-Host ("  -> {0}" -f $result) -ForegroundColor $(if ($isStop) { 'Red' } else { 'White' })
        $ctx.Log += ("{0}: {1}" -f $s.Id, $result)
        if ($isStop) { $halted = $true; break }
    }
    if ($s.Type -eq 'manual') {
        $followups += $s.Title
        if (-not $NonInteractive) { Read-Host '  Press Enter when done' | Out-Null }
    }
}

Write-Banner 'Summary'
$auto = @($steps | Where-Object { $_.Type -eq 'auto' }).Count
$manual = @($steps | Where-Object { $_.Type -eq 'manual' }).Count
if ($halted) { Write-Host 'Run halted by a safety guard. Nothing further was attempted.' -ForegroundColor Red }
Write-Host ("Automated steps: {0}" -f $auto)
Write-Host ("Manual follow-ups: {0}" -f $manual)
foreach ($f in $followups) { Write-Host ("  - {0}" -f $f) -ForegroundColor Yellow }

Set-Content -Path $logPath -Value ($ctx.Log -join "`n")
Write-Host ''
Write-Host ("Log written: {0}" -f $logPath) -ForegroundColor DarkGray
