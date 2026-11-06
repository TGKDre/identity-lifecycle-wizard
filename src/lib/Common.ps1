Set-StrictMode -Version Latest

function Write-Banner {
    param([Parameter(Mandatory)][string]$Text)
    $line = '=' * 64
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host ("  {0}" -f $Text) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkCyan
}

function Write-StepHeader {
    param([int]$Index, [int]$Total, [string]$Title, [string]$Type)
    $tag = if ($Type -eq 'manual') { '[ MANUAL ]' } else { '[  auto  ]' }
    Write-Host ''
    Write-Host ("Step {0}/{1} {2} {3}" -f $Index, $Total, $tag, $Title) -ForegroundColor Yellow
}

function Write-Detail {
    param([string]$Label, [string]$Text)
    if ($Text) { Write-Host ("  {0}: {1}" -f $Label, $Text) -ForegroundColor Gray }
}

function Confirm-Proceed {
    param([string]$Prompt = 'Proceed?', [switch]$NonInteractive)
    if ($NonInteractive) {
        Write-Host '  (non-interactive: auto-approved)' -ForegroundColor DarkGray
        return $true
    }
    $ans = Read-Host ("{0} [y/N]" -f $Prompt)
    return ($ans -match '^(y|yes)$')
}

function New-LogFile {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Mode)
    $dir = Join-Path $Root 'logs'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $path = Join-Path $dir ("{0}_{1}.log" -f $Mode, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    return $path
}
