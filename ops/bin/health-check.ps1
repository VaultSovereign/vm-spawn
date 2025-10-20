<# 
  ops/bin/health-check.ps1 — Native PowerShell health check for VaultMesh bootstrap
  Exit codes:
    0 = OK, 1 = WARNING/partial, 2 = ERROR
#>
[CmdletBinding()]
param(
  [switch]$VerboseOutput
)

function Test-Command { 
  param([string]$Name) 
  try { Get-Command $Name -ErrorAction Stop | Out-Null; return $true } catch { return $false } 
}

$results = @()
$fail = 0
$warn = 0
function Add-Check($Name, $Status, $Details) {
  $script:results += [pscustomobject]@{ Check = $Name; Status = $Status; Details = $Details }
  if ($Status -eq 'ERROR') { $script:fail++ }
  elseif ($Status -eq 'WARN') { $script:warn++ }
}

# PowerShell version
try {
  $psver = $PSVersionTable.PSVersion.ToString()
  if ([version]$PSVersionTable.PSVersion -ge [version]'5.1') { Add-Check 'PowerShell' 'OK' "Version $psver" }
  else { Add-Check 'PowerShell' 'WARN' "Old version $psver (<5.1). Some features may fail." }
} catch { Add-Check 'PowerShell' 'ERROR' $_.Exception.Message }

# ExecutionPolicy overview
try {
  $polList = (Get-ExecutionPolicy -List | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }) -join '; '
  Add-Check 'ExecutionPolicy' 'OK' $polList
} catch { Add-Check 'ExecutionPolicy' 'WARN' "Could not read execution policy: $($_.Exception.Message)" }

# Git
if (Test-Command git) { Add-Check 'Git' 'OK' 'git available' } else { Add-Check 'Git' 'WARN' 'git not found; zip fallback will be used' }

# .NET (dotnet)
if (Test-Command dotnet) {
  try {
    $info = (& dotnet --info) -join ' | '
    Add-Check '.NET' 'OK' ($info.Substring(0,[Math]::Min($info.Length,160)))
  } catch {
    Add-Check '.NET' 'WARN' 'dotnet present but --info failed'
  }
} else { Add-Check '.NET' 'WARN' '.NET (dotnet) not found' }

# WSL
if (Test-Command wsl) {
  try {
    $status = (& wsl.exe --status) 2>$null
    if ($status) {
      $line = ($status | Select-String -Pattern 'Default Version').Line
      Add-Check 'WSL' 'OK' ((($line -ne $null) ? $line : ($status -join ' | ')).ToString().Substring(0,[Math]::Min(($status -join ' | ').Length,160)))
    } else { Add-Check 'WSL' 'OK' 'wsl present (status output empty)' }
  } catch {
    Add-Check 'WSL' 'WARN' "wsl present but --status failed: $($_.Exception.Message)"
  }
} else { Add-Check 'WSL' 'WARN' 'wsl.exe not found' }

# Bash (optional)
if (Test-Command bash) { Add-Check 'bash' 'OK' 'bash available (Git Bash/WSL)' } else { Add-Check 'bash' 'WARN' 'bash not found; only native PS steps will run' }

# Python (optional)
if (Test-Command python) { Add-Check 'Python' 'OK' 'python available' }
elseif (Test-Command python3) { Add-Check 'Python' 'OK' 'python3 available' }
else { Add-Check 'Python' 'WARN' 'python not found' }

# Docker (optional)
if (Test-Command docker) { Add-Check 'Docker' 'OK' 'docker available' } else { Add-Check 'Docker' 'WARN' 'docker not found' }

# Network to GitHub
try {
  $uri = 'https://github.com'
  $resp = Invoke-WebRequest -Uri $uri -Method Head -TimeoutSec 5 -UseBasicParsing
  if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) { Add-Check 'Network:GitHub' 'OK' "HTTP $($resp.StatusCode)" }
  else { Add-Check 'Network:GitHub' 'WARN' "HTTP $($resp.StatusCode)" }
} catch {
  Add-Check 'Network:GitHub' 'WARN' "Network check failed: $($_.Exception.Message)"
}

# Repository presence
try {
  $repoPath = Join-Path (Join-Path $env:USERPROFILE 'Downloads') 'vm-spawn'
  if (Test-Path $repoPath) { Add-Check 'Repo:vm-spawn' 'OK' $repoPath }
  else { Add-Check 'Repo:vm-spawn' 'WARN' 'Not present yet' }
} catch { Add-Check 'Repo:vm-spawn' 'ERROR' $_.Exception.Message }

# Output
$results | Format-Table -AutoSize | Out-String | Write-Host
if ($VerboseOutput) {
  $json = $results | ConvertTo-Json -Depth 5
  Write-Host "`nRaw:"
  Write-Host $json
}

if ($fail -gt 0) { exit 2 }
elseif ($warn -gt 0) { exit 1 }
else { exit 0 }
